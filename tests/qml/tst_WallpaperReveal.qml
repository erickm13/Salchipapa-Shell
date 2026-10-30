import QtQuick
import QtTest
import "../../shell/background" as Background

TestCase {
    id: testCase
    name: "WallpaperReveal"
    when: windowShown
    visible: true
    width: 320
    height: 200

    property var wallpaper
    readonly property url redSource: solidImage("red")
    readonly property url blueSource: solidImage("blue")
    readonly property url greenSource: solidImage("lime")

    function solidImage(color) {
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="200"><rect width="320" height="200" fill="' + color + '"/></svg>'
        );
    }

    Component {
        id: wallpaperComponent
        Background.WallpaperReveal {
            width: 320
            height: 200
            origin: Qt.point(0.5, 0.5)
            duration: 120
        }
    }

    function init() {
        wallpaper = createTemporaryObject(wallpaperComponent, testCase);
        verify(wallpaper !== null);
        wallpaper.source = redSource;
        tryVerify(() => wallpaper.displayedSource.toString() === redSource.toString());
    }

    function test_initialImageHasNoAnimation() {
        verify(!wallpaper.transitioning);
        compare(grabImage(wallpaper).pixel(160, 100), Qt.color("red"));
    }

    function test_circleRevealsNewImageOverOld() {
        wallpaper.duration = 1000;
        wallpaper.source = blueSource;
        tryVerify(() => wallpaper.transitioning && wallpaper.progress > 0.15);
        compare(wallpaper.displayedSource, redSource);
        const image = grabImage(wallpaper);
        compare(image.pixel(160, 100), Qt.color("blue"));
        compare(image.pixel(2, 2), Qt.color("red"));
        tryVerify(() => wallpaper.displayedSource.toString() === blueSource.toString());
        verify(!wallpaper.transitioning);
        compare(grabImage(wallpaper).pixel(2, 2), Qt.color("blue"));
    }

    function test_originNearCornerCoversOppositeCorner() {
        wallpaper.origin = Qt.point(0, 0);
        wallpaper.duration = 1000;
        wallpaper.source = blueSource;
        tryVerify(() => wallpaper.transitioning && wallpaper.progress > 0.15);
        const image = grabImage(wallpaper);
        compare(image.pixel(2, 2), Qt.color("blue"));
        compare(image.pixel(318, 198), Qt.color("red"));
        tryVerify(() => wallpaper.displayedSource.toString() === blueSource.toString());
        compare(grabImage(wallpaper).pixel(318, 198), Qt.color("blue"));
    }

    function test_latestSelectionWinsDuringAnimation() {
        wallpaper.duration = 200;
        wallpaper.source = blueSource;
        tryVerify(() => wallpaper.transitioning);
        wallpaper.source = redSource;
        wallpaper.source = greenSource;
        tryVerify(() => wallpaper.displayedSource.toString() === greenSource.toString());
        verify(!wallpaper.transitioning);
        compare(grabImage(wallpaper).pixel(160, 100), Qt.color("lime"));
    }

    function test_imageCropDoesNotJumpAtEndOfReveal() {
        const croppedSource = "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="200">'
            + '<rect width="1000" height="200" fill="red"/>'
            + '<rect x="400" width="200" height="200" fill="blue"/></svg>'
        );
        wallpaper.duration = 1000;
        wallpaper.source = croppedSource;
        tryVerify(() => wallpaper.transitioning && wallpaper.progress > 0.75);
        const during = grabImage(wallpaper).pixel(100, 100);
        tryVerify(() => !wallpaper.transitioning);
        compare(wallpaper.displayedSource, wallpaper.source);
        const after = grabImage(wallpaper).pixel(100, 100);
        compare(after, Qt.color("blue"));
        compare(during, after);
    }

    function test_reducedMotionAndZeroDurationSkipAnimation() {
        wallpaper.reduceMotion = true;
        wallpaper.source = blueSource;
        tryVerify(() => wallpaper.displayedSource.toString() === blueSource.toString());
        verify(!wallpaper.transitioning);
        wallpaper.reduceMotion = false;
        wallpaper.duration = 0;
        wallpaper.source = greenSource;
        tryVerify(() => wallpaper.displayedSource.toString() === greenSource.toString());
        verify(!wallpaper.transitioning);
    }

    function test_enablingReducedMotionFinishesRunningTransition() {
        wallpaper.duration = 1000;
        wallpaper.source = blueSource;
        tryVerify(() => wallpaper.transitioning);
        wallpaper.reduceMotion = true;
        compare(wallpaper.displayedSource, blueSource);
        verify(!wallpaper.transitioning);
    }

    function test_failedLoadKeepsPreviousWallpaper() {
        ignoreWarning(/.*Cannot open.*wallpaper-reveal-nonexistent-image.png/);
        wallpaper.source = "file:///tmp/wallpaper-reveal-nonexistent-image.png";
        wait(150);
        compare(wallpaper.displayedSource, redSource);
        verify(!wallpaper.transitioning);
        compare(grabImage(wallpaper).pixel(160, 100), Qt.color("red"));
    }
}
