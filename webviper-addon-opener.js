//
// This positions a extension pop up window in the current screen and browser window
// -----------------------------------------------------------------------------------------
// Globals
// -----------------------------------------------------------------------------------------
const useChrome = typeof (browser) === 'undefined';
const windowData = {
  type: 'panel',
  allowScriptsToClose: true,
  height: 514,
  width: 634,
  titlePreface: 'webViper '
};

const getInfoParams = {
  windowTypes: ['normal']
};

function setupWindow (parentWindow) {
  const top = parentWindow.top;
  const left = parentWindow.left;
  const width = parentWindow.width;
  const height = parentWindow.height;

  const subWinWidth = windowData.width;
  const subWinHeight = windowData.height;

  windowData.top = Math.round((height * 0.5) + top - (subWinHeight * 0.5));
  windowData.left = Math.round((width * 0.5) + left - (subWinWidth * 0.5));
  if (!useChrome) {
    browser.windows.create(windowData);
  } else {
    chrome.windows.create(windowData);
  }
}

if (!useChrome) {
  const windowURL = browser.runtime.getURL('/addon-srcs/webviper-addon-ui.html');
  windowData.url = windowURL;
  browser.windows.getCurrent(getInfoParams).then(setupWindow);
} else {
  const windowURL = chrome.runtime.getURL('/addon-srcs/webviper-addon-ui.html');
  windowData.url = windowURL;
  chrome.windows.getCurrent(getInfoParams).then(setupWindow);
}
