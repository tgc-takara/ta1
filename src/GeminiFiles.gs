/**
 * Gemini File API（resumable upload）。動画を Gemini にアップロードして fileUri を得る。
 * Docs: https://ai.google.dev/api/files
 */
var GeminiFiles = (function () {
  var BASE = 'https://generativelanguage.googleapis.com';

  function apiKey_() { return Config.geminiApiKey(); }

  /**
   * Drive の fileId を受け取り、Gemini File API にアップロードして {uri, mimeType} を返す。
   * 大きすぎる blob（GAS の UrlFetchApp サイズ上限 ~50MB リクエスト）は事前にチェック。
   */
  function uploadFromDrive(fileId) {
    var blob = DriveApp.getFileById(fileId).getBlob();
    var bytes = blob.getBytes();
    if (bytes.length > 50 * 1024 * 1024) {
      throw new Error('動画が大きすぎます（' + Math.round(bytes.length / 1024 / 1024) + 'MB）。60秒以内・720pで撮影してください。');
    }
    var mimeType = blob.getContentType() || 'video/mp4';
    var displayName = blob.getName() || ('video_' + Date.now());

    // Step 1: start resumable upload
    var startUrl = BASE + '/upload/v1beta/files?key=' + encodeURIComponent(apiKey_());
    var startRes = UrlFetchApp.fetch(startUrl, {
      method: 'post',
      muteHttpExceptions: true,
      headers: {
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': String(bytes.length),
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json'
      },
      payload: JSON.stringify({ file: { display_name: displayName } })
    });
    if (startRes.getResponseCode() >= 300) {
      throw new Error('Gemini File API start 失敗: ' + startRes.getResponseCode() + ' ' + startRes.getContentText());
    }
    var uploadUrl = startRes.getHeaders()['X-Goog-Upload-URL'] || startRes.getHeaders()['x-goog-upload-url'];
    if (!uploadUrl) throw new Error('Gemini File API: upload URL を取得できませんでした');

    // Step 2: upload + finalize
    var putRes = UrlFetchApp.fetch(uploadUrl, {
      method: 'post',
      muteHttpExceptions: true,
      headers: {
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
        'Content-Type': mimeType
      },
      payload: bytes
    });
    if (putRes.getResponseCode() >= 300) {
      throw new Error('Gemini File API upload 失敗: ' + putRes.getResponseCode() + ' ' + putRes.getContentText());
    }
    var parsed = JSON.parse(putRes.getContentText());
    var file = parsed.file || parsed;
    // 動画は ACTIVE になるまで待つ
    var ready = waitUntilActive_(file.name);
    return { uri: ready.uri || file.uri, mimeType: ready.mimeType || mimeType, name: file.name };
  }

  function waitUntilActive_(fileName) {
    var url = BASE + '/v1beta/' + fileName + '?key=' + encodeURIComponent(apiKey_());
    var maxWaitMs = 120 * 1000; // 最大2分
    var start = Date.now();
    while (Date.now() - start < maxWaitMs) {
      var res = UrlFetchApp.fetch(url, { method: 'get', muteHttpExceptions: true });
      if (res.getResponseCode() >= 300) {
        throw new Error('Gemini File API status 失敗: ' + res.getResponseCode() + ' ' + res.getContentText());
      }
      var body = JSON.parse(res.getContentText());
      if (body.state === 'ACTIVE') return body;
      if (body.state === 'FAILED') throw new Error('Gemini File 処理失敗: ' + JSON.stringify(body));
      Utilities.sleep(2000);
    }
    throw new Error('Gemini File の ACTIVE 遷移待機タイムアウト');
  }

  function deleteFile(name) {
    try {
      var url = BASE + '/v1beta/' + name + '?key=' + encodeURIComponent(apiKey_());
      UrlFetchApp.fetch(url, { method: 'delete', muteHttpExceptions: true });
    } catch (e) { /* ignore */ }
  }

  return {
    uploadFromDrive: uploadFromDrive,
    deleteFile: deleteFile
  };
})();
