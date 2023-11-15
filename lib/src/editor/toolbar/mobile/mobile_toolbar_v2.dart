import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class MobileToolbarV2 extends StatelessWidget {
  const MobileToolbarV2({
    super.key,
    required this.editorState,
    required this.toolbarItems,
  });

  final EditorState editorState;
  final List<MobileToolbarItem> toolbarItems;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Selection?>(
      valueListenable: editorState.selectionNotifier,
      builder: (_, Selection? selection, __) {
        // if the selection is null, hide the toolbar
        if (selection == null) {
          return const SizedBox.shrink();
        }

        Widget child = _MobileToolbar(
          editorState: editorState,
          toolbarItems: toolbarItems,
        );

        // if the MobileToolbarTheme is not provided, provide it
        if (MobileToolbarTheme.maybeOf(context) == null) {
          child = MobileToolbarTheme(
            child: child,
          );
        }

        return RepaintBoundary(
          child: child,
        );
      },
    );
  }
}

class _MobileToolbar extends StatefulWidget {
  const _MobileToolbar({
    required this.editorState,
    required this.toolbarItems,
  });

  final EditorState editorState;
  final List<MobileToolbarItem> toolbarItems;

  @override
  State<_MobileToolbar> createState() => _MobileToolbarState();
}

class _MobileToolbarState extends State<_MobileToolbar>
    implements MobileToolbarWidgetService {
  // used to control the toolbar menu items
  ValueNotifier<bool> showMenuNotifier = ValueNotifier(false);

  // when the users click the menu item, the keyboard will be hidden,
  //  but in this case, we don't want to update the cached keyboard height.
  // This is because we want to keep the same height when the menu is shown.
  bool canUpdateCachedKeyboardHeight = true;
  ValueNotifier<double> cachedKeyboardHeight = ValueNotifier(0.0);
  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  // used to check if click the same item again
  int? selectedMenuIndex;

  @override
  void dispose() {
    showMenuNotifier.dispose();
    cachedKeyboardHeight.dispose();

    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();

    canUpdateCachedKeyboardHeight = true;
    closeItemMenu();
    _closeKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    // update the keyboard height here.
    // try to get the height in `didChangeMetrics`, but it's not accurate.
    if (canUpdateCachedKeyboardHeight) {
      cachedKeyboardHeight.value = keyboardHeight;
    }
    // toolbar
    //  - if the menu is shown, the toolbar will be pushed up by the height of the menu
    //  - otherwise, add a spacer to push the toolbar up when the keyboard is shown
    return Column(
      children: [
        _buildToolbar(context),
        _buildMenuOrSpacer(context),
      ],
    );
  }

  @override
  void closeItemMenu() {
    showMenuNotifier.value = false;
  }

  void showItemMenu() {
    showMenuNotifier.value = true;
  }

  // toolbar list view and close keyboard/menu button
  Widget _buildToolbar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final style = MobileToolbarTheme.of(context);

    return Container(
      width: width,
      height: style.toolbarHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: style.itemOutlineColor,
          ),
          bottom: BorderSide(color: style.itemOutlineColor),
        ),
        color: style.backgroundColor,
      ),
      child: Row(
        children: [
          // toolbar list view
          Expanded(
            child: _ToolbarItemListView(
              toolbarItems: widget.toolbarItems,
              editorState: widget.editorState,
              toolbarWidgetService: this,
              itemWithMenuOnPressed: (index) {
                // click the same one
                if (selectedMenuIndex == index && showMenuNotifier.value) {
                  // if the menu is shown, close it and show the keyboard
                  closeItemMenu();
                  _showKeyboard();
                  // update the cached keyboard height after the keyboard is shown
                  Future.delayed(const Duration(milliseconds: 500), () {
                    canUpdateCachedKeyboardHeight = true;
                  });
                } else {
                  canUpdateCachedKeyboardHeight = false;
                  selectedMenuIndex = index;
                  showItemMenu();
                  _closeKeyboard();
                }
              },
            ),
          ),
          // divider
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 4.0,
            ),
            child: VerticalDivider(),
          ),
          // close menu or close keyboard button
          ValueListenableBuilder(
            valueListenable: showMenuNotifier,
            builder: (_, showingMenu, __) {
              return _CloseKeyboardOrMenuButton(
                showingMenu: showingMenu,
                onPressed: () {
                  if (showingMenu) {
                    // close the menu and show the keyboard
                    closeItemMenu();
                    _showKeyboard();
                  } else {
                    // close the keyboard and clear the selection
                    // if the selection is null, the keyboard and the toolbar will be hidden automatically
                    widget.editorState.selection = null;
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // if there's no menu, we need to add a spacer to push the toolbar up when the keyboard is shown
  Widget _buildMenuOrSpacer(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: cachedKeyboardHeight,
      builder: (_, height, ___) {
        return ValueListenableBuilder(
          valueListenable: showMenuNotifier,
          builder: (_, showingMenu, __) {
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: !(showMenuNotifier.value && selectedMenuIndex != null)
                  ? const SizedBox.shrink()
                  : MobileToolbarItemMenu(
                      editorState: widget.editorState,
                      itemMenuBuilder: () => widget
                          .toolbarItems[selectedMenuIndex!].itemMenuBuilder!
                          .call(
                        context,
                        widget.editorState,
                        this,
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  void _showKeyboard() {
    final selection = widget.editorState.selection;
    if (selection != null) {
      widget.editorState.service.keyboardService?.enableKeyBoard(selection);
    }
  }

  void _closeKeyboard() {
    widget.editorState.service.keyboardService?.closeKeyboard();
  }
}

class _ToolbarItemListView extends StatelessWidget {
  const _ToolbarItemListView({
    required this.toolbarItems,
    required this.editorState,
    required this.toolbarWidgetService,
    required this.itemWithMenuOnPressed,
  });

  final Function(int index) itemWithMenuOnPressed;
  final List<MobileToolbarItem> toolbarItems;
  final EditorState editorState;
  final MobileToolbarWidgetService toolbarWidgetService;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        final toolbarItem = toolbarItems[index];
        final icon = toolbarItem.itemIconBuilder?.call(
          context,
          editorState,
          toolbarWidgetService,
        );
        if (icon == null) {
          return const SizedBox.shrink();
        }
        return IconButton(
          icon: icon,
          onPressed: () {
            if (toolbarItem.hasMenu) {
              // open /close current item menu through its parent widget(MobileToolbarWidget)
              itemWithMenuOnPressed.call(index);
            } else {
              // close menu if other item's menu is still on the screen
              toolbarWidgetService.closeItemMenu();
              toolbarItems[index].actionHandler?.call(
                    context,
                    editorState,
                  );
            }
          },
        );
      },
      itemCount: toolbarItems.length,
      scrollDirection: Axis.horizontal,
    );
  }
}

class _CloseKeyboardOrMenuButton extends StatelessWidget {
  const _CloseKeyboardOrMenuButton({
    required this.showingMenu,
    required this.onPressed,
  });

  final bool showingMenu;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      onPressed: onPressed,
      icon: showingMenu
          ? const AFMobileIcon(
              afMobileIcons: AFMobileIcons.close,
            )
          : const Icon(Icons.keyboard_hide),
    );
  }
}