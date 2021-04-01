# How to create a background image for `create-dmg` that supports both retina and non-retina macs

- Let's say your background normal resolution is 600x400
- Export a png file at 2x resolution, 1200x800
- Its DPI setting should be the default value, 72. Check:
    ```
    sips --getProperty dpiHeight bg.png
    ```
    If it is 144, we're done, no need to follow along.
- Set its DPI to 144:
    ```
    sips --setProperty dpiWidth 144 --setProperty dpiHeight 144 bg.png
    ```
- Feed that png to `create-dmg` with `window-size` option is set to 600x400, like:
    ```
    create-dmg --window-size 600 400
    ```
- You may want to add a little extra height (like 15-20 or so), because title bar is included to 400.


Credit: https://github.com/create-dmg/create-dmg/issues/20#issuecomment-472081430
