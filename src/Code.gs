/**
 * Web App エントリ + クライアントから呼び出す api_* RPC 層。
 * google.script.run からは関数名がトップレベルに見える必要があるので、
 * ここでグローバル関数として公開する。
 */

function doGet() {
  var tpl = HtmlService.createTemplateFromFile('index');
  return tpl.evaluate()
    .setTitle('名刺管理')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/** HTML テンプレート内で CSS / JS をインクルードする */
function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

/** 初期情報（現在ユーザーのメール、スキーマ列名） */
function api_bootstrap() {
  return {
    user: CardSheet._currentUser(),
    columns: CardSheet.COLUMNS,
    model: Config.geminiModel()
  };
}

// ===== 動画アップロード（チャンク） =====
function api_startVideoUpload(mimeType) {
  return CardDrive.startVideoUpload(mimeType);
}
function api_appendVideoChunk(sessionId, base64, index) {
  return CardDrive.appendVideoChunk(sessionId, base64, index);
}
function api_finishVideoUpload(sessionId, totalParts) {
  return CardDrive.finishVideoUpload(sessionId, totalParts, 'cards');
}

// ===== 動画 OCR =====
function api_extractFromVideo(videoFileId) {
  return CardOcr.extractFromVideo(videoFileId);
}

// ===== 画像 1枚 OCR（補助） =====
function api_extractFromImage(imageDataUrl) {
  return CardOcr.extractFromImage(imageDataUrl);
}

// ===== 静止画アップロード（サムネ） =====
function api_uploadCardImage(imageDataUrl) {
  return CardDrive.saveImage(imageDataUrl, 'card');
}

// ===== 名刺 CRUD =====
function api_listCards() {
  return CardSheet.listAll();
}

function api_createCardsBatch(cards) {
  if (!Array.isArray(cards)) throw new Error('cards は配列で渡してください');
  return CardSheet.appendMany(cards);
}

function api_updateCard(id, patch) {
  return CardSheet.update(id, patch);
}

function api_deleteCard(id) {
  return CardSheet.remove(id);
}

// ===== テスト用ユーティリティ（Apps Script エディタから実行） =====
function test_setup() { return setup(); }

function test_bootstrap() {
  Logger.log(JSON.stringify(api_bootstrap()));
}
