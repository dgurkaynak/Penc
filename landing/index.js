import fs from 'fs';
import videoMoveUrl from './assets/move.mp4'
import videoPinchUrl from './assets/pinch.mp4'
import videoSwipeUrl from './assets/swipe.mp4'

const packageJsonRaw = fs.readFileSync(__dirname + '/../package.json', 'utf8');
const packageJson = JSON.parse(packageJsonRaw + '');
const videoUrls = {
    move: videoMoveUrl,
    pinch: videoPinchUrl,
    swipe: videoSwipeUrl
};

const downloadButtonEl = document.getElementById('download-button');
downloadButtonEl.setAttribute('href', 'https://github.com/dgurkaynak/Penc/releases/download/' + packageJson.version + '/Penc-' + packageJson.version + '.dmg');
downloadButtonEl.textContent = 'Download Penc ' + packageJson.version;

let activeShowcaseItem = null;
let isShowcaseDirty = false;
const showcaseMoveEl = document.getElementById('showcase-move');
const showcasePinchEl = document.getElementById('showcase-pinch');
const showcaseSwipeEl = document.getElementById('showcase-swipe');
const videoEl = document.getElementById('video');

function getShowcaseItemElementByName(name) {
    switch (name) {
        case 'move':
            return showcaseMoveEl;
        case 'pinch':
            return showcasePinchEl;
        case 'swipe':
            return showcaseSwipeEl;
    }
}

function getNextShowcaseItem(name) {
    switch (name) {
        case 'move':
            return 'pinch';
        case 'pinch':
            return 'swipe';
        case 'swipe':
            return 'move';
    }
}

function displayShowcaseItem(item) {
    if (item == activeShowcaseItem) return;
    showcaseMoveEl.classList.remove('selected');
    showcasePinchEl.classList.remove('selected');
    showcaseSwipeEl.classList.remove('selected');
    getShowcaseItemElementByName(item).classList.add('selected');
    activeShowcaseItem = item;
    videoEl.src = videoUrls[item];
}

function onShowcaseItemHover(item) {
    displayShowcaseItem(item);
    isShowcaseDirty = true;
}

function onVideoEnded() {
    if (isShowcaseDirty) {
        const playPromise = videoEl.play();
        if (playPromise && playPromise.catch) {
            playPromise.catch((err) => {
                console.warn('Could not play video element', err);
            });
        }
        return;
    }
    const nextItem = getNextShowcaseItem(activeShowcaseItem);
    displayShowcaseItem(nextItem);
}

showcaseMoveEl.addEventListener('mouseover', onShowcaseItemHover.bind(null, 'move'));
showcasePinchEl.addEventListener('mouseover', onShowcaseItemHover.bind(null, 'pinch'));
showcaseSwipeEl.addEventListener('mouseover', onShowcaseItemHover.bind(null, 'swipe'));
videoEl.addEventListener('ended', onVideoEnded);
displayShowcaseItem('move');
