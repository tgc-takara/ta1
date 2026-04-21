/**
 * 初回セットアップ。Apps Script エディタから手動で1回だけ実行する。
 * - Script Properties の検証
 * - Spreadsheet のヘッダと _meta 作成
 * - Drive フォルダの存在確認
 */
function setup() {
  Config.verifyAll();
  CardSheet.ensureSheets();

  // Drive フォルダの存在確認（権限エラーの早期発見）
  DriveApp.getFolderById(Config.imageFolderId()).getName();
  DriveApp.getFolderById(Config.videoFolderId()).getName();

  // Gemini API キーの疎通は test_ocr() 等で。ここでは存在チェックのみ。
  Logger.log('setup completed at ' + new Date().toISOString());
  return 'OK';
}
