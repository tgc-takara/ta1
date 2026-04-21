/**
 * Drive への保存。画像・動画のチャンク受信対応。
 * base64 データURL（"data:video/mp4;base64,..." 形式）を受け付ける。
 */
var CardDrive = (function () {
  function decodeDataUrl_(dataUrl) {
    var idx = dataUrl.indexOf(',');
    if (idx < 0) throw new Error('不正な dataURL です');
    var meta = dataUrl.substring(5, idx); // "image/jpeg;base64"
    var semi = meta.indexOf(';');
    var mimeType = semi >= 0 ? meta.substring(0, semi) : meta;
    var b64 = dataUrl.substring(idx + 1);
    var bytes = Utilities.base64Decode(b64);
    return { mimeType: mimeType, bytes: bytes };
  }

  function ext_(mime) {
    if (!mime) return 'bin';
    var m = mime.toLowerCase();
    if (m.indexOf('jpeg') >= 0) return 'jpg';
    if (m.indexOf('png') >= 0) return 'png';
    if (m.indexOf('webp') >= 0) return 'webp';
    if (m.indexOf('mp4') >= 0) return 'mp4';
    if (m.indexOf('webm') >= 0) return 'webm';
    if (m.indexOf('quicktime') >= 0) return 'mov';
    return m.split('/')[1] || 'bin';
  }

  /**
   * 画像保存。dataUrl から Drive にファイル作成し fileId / viewUrl を返す。
   */
  function saveImage(dataUrl, namePrefix) {
    var dec = decodeDataUrl_(dataUrl);
    var blob = Utilities.newBlob(dec.bytes, dec.mimeType,
      (namePrefix || 'card') + '_' + Date.now() + '.' + ext_(dec.mimeType));
    var folder = DriveApp.getFolderById(Config.imageFolderId());
    var file = folder.createFile(blob);
    return {
      fileId: file.getId(),
      viewUrl: 'https://drive.google.com/uc?id=' + file.getId(),
      thumbnailUrl: 'https://drive.google.com/thumbnail?id=' + file.getId()
    };
  }

  /**
   * 動画保存（単一 dataURL で受ける。大きすぎる場合は saveVideoChunk を使う）。
   */
  function saveVideo(dataUrl, namePrefix) {
    var dec = decodeDataUrl_(dataUrl);
    var blob = Utilities.newBlob(dec.bytes, dec.mimeType,
      (namePrefix || 'video') + '_' + Date.now() + '.' + ext_(dec.mimeType));
    var folder = DriveApp.getFolderById(Config.videoFolderId());
    var file = folder.createFile(blob);
    return { fileId: file.getId(), mimeType: dec.mimeType };
  }

  /**
   * チャンク動画アップロード。
   * session==null かつ first==true で新規セッション作成。
   * チャンクごとに既存ファイルに base64 を追記する簡易実装：
   * - 実体はキャッシュに積み、最後のチャンク（last==true）で結合して Drive に書き込む。
   */
  var CHUNK_PREFIX = 'vchunk:';

  function startVideoUpload(mimeType) {
    var sessionId = Utilities.getUuid();
    var cache = CacheService.getUserCache();
    cache.put(CHUNK_PREFIX + sessionId + ':meta', JSON.stringify({
      mimeType: mimeType || 'video/mp4',
      parts: 0
    }), 21600); // 6h
    return { sessionId: sessionId };
  }

  function appendVideoChunk(sessionId, base64, index) {
    var cache = CacheService.getUserCache();
    var key = CHUNK_PREFIX + sessionId + ':' + index;
    // CacheService の1値は100KBまで。クライアントで<90KB に刻む前提。
    cache.put(key, base64, 21600);
    var metaKey = CHUNK_PREFIX + sessionId + ':meta';
    var meta = JSON.parse(cache.get(metaKey) || '{}');
    meta.parts = Math.max(meta.parts || 0, index + 1);
    cache.put(metaKey, JSON.stringify(meta), 21600);
    return { ok: true, parts: meta.parts };
  }

  function finishVideoUpload(sessionId, totalParts, namePrefix) {
    var cache = CacheService.getUserCache();
    var metaKey = CHUNK_PREFIX + sessionId + ':meta';
    var meta = JSON.parse(cache.get(metaKey) || '{}');
    var mimeType = meta.mimeType || 'video/mp4';
    var keys = [];
    for (var i = 0; i < totalParts; i++) keys.push(CHUNK_PREFIX + sessionId + ':' + i);
    var bulk = cache.getAll(keys);
    var combined = [];
    for (var j = 0; j < totalParts; j++) {
      var b64 = bulk[keys[j]];
      if (b64 == null) throw new Error('チャンク ' + j + ' が欠落しました。再送してください。');
      var bytes = Utilities.base64Decode(b64);
      for (var k = 0; k < bytes.length; k++) combined.push(bytes[k]);
    }
    var blob = Utilities.newBlob(combined, mimeType,
      (namePrefix || 'video') + '_' + Date.now() + '.' + ext_(mimeType));
    var folder = DriveApp.getFolderById(Config.videoFolderId());
    var file = folder.createFile(blob);
    cache.removeAll(keys.concat([metaKey]));
    return { fileId: file.getId(), mimeType: mimeType, sizeBytes: combined.length };
  }

  function getFileBlob(fileId) { return DriveApp.getFileById(fileId).getBlob(); }

  function trash(fileId) {
    try { DriveApp.getFileById(fileId).setTrashed(true); } catch (e) { /* ignore */ }
  }

  return {
    saveImage: saveImage,
    saveVideo: saveVideo,
    startVideoUpload: startVideoUpload,
    appendVideoChunk: appendVideoChunk,
    finishVideoUpload: finishVideoUpload,
    getFileBlob: getFileBlob,
    trash: trash
  };
})();
