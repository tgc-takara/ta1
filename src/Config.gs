/**
 * Script Properties を検証付きで読み出すラッパー。
 */
var Config = (function () {
  var KEYS = {
    SHEET_ID: 'SHEET_ID',
    DRIVE_IMAGE_FOLDER_ID: 'DRIVE_IMAGE_FOLDER_ID',
    DRIVE_VIDEO_FOLDER_ID: 'DRIVE_VIDEO_FOLDER_ID',
    GEMINI_API_KEY: 'GEMINI_API_KEY',
    GEMINI_MODEL: 'GEMINI_MODEL'
  };

  var DEFAULT_MODEL = 'gemini-2.5-flash';

  function get(key, required) {
    var v = PropertiesService.getScriptProperties().getProperty(key);
    if (required && !v) {
      throw new Error('Script Property "' + key + '" が未設定です。Apps Script エディタのプロジェクト設定から登録してください。');
    }
    return v;
  }

  return {
    KEYS: KEYS,
    sheetId: function () { return get(KEYS.SHEET_ID, true); },
    imageFolderId: function () { return get(KEYS.DRIVE_IMAGE_FOLDER_ID, true); },
    videoFolderId: function () { return get(KEYS.DRIVE_VIDEO_FOLDER_ID, true); },
    geminiApiKey: function () { return get(KEYS.GEMINI_API_KEY, true); },
    geminiModel: function () { return get(KEYS.GEMINI_MODEL, false) || DEFAULT_MODEL; },
    verifyAll: function () {
      [KEYS.SHEET_ID, KEYS.DRIVE_IMAGE_FOLDER_ID, KEYS.DRIVE_VIDEO_FOLDER_ID, KEYS.GEMINI_API_KEY]
        .forEach(function (k) { get(k, true); });
      return true;
    }
  };
})();
