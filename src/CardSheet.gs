/**
 * `cards` シートの CRUD。列順は COLUMNS で固定。
 */
var CardSheet = (function () {
  var SHEET_NAME = 'cards';
  var META_SHEET_NAME = '_meta';
  var SCHEMA_VERSION = 1;

  // 列順（A列から）
  var COLUMNS = [
    'id', 'createdAt', 'updatedAt', 'owner',
    'imageFileId', 'imageUrl',
    'sourceVideoFileId', 'sourceTimestampSec',
    '氏名', 'ふりがな', '会社名', '部署', '役職',
    'Email', '電話', '携帯', 'FAX',
    '郵便番号', '住所', 'URL',
    'Twitter', 'LinkedIn', 'Facebook', 'Instagram',
    '出会った日', '出会った場所', 'メモ',
    'タグ'
  ];

  function spreadsheet_() { return SpreadsheetApp.openById(Config.sheetId()); }

  function ensureSheets_() {
    var ss = spreadsheet_();
    var sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
    }
    // ヘッダ
    var header = sheet.getRange(1, 1, 1, COLUMNS.length).getValues()[0];
    var hasHeader = header.join('') !== '';
    if (!hasHeader) {
      sheet.getRange(1, 1, 1, COLUMNS.length).setValues([COLUMNS]);
      sheet.setFrozenRows(1);
    }
    var meta = ss.getSheetByName(META_SHEET_NAME) || ss.insertSheet(META_SHEET_NAME);
    if (meta.getRange('A1').getValue() !== 'key') {
      meta.getRange(1, 1, 1, 2).setValues([['key', 'value']]);
      meta.getRange(2, 1, 2, 2).setValues([
        ['schemaVersion', SCHEMA_VERSION],
        ['initializedAt', new Date().toISOString()]
      ]);
    }
    return sheet;
  }

  function sheet_() {
    var ss = spreadsheet_();
    var sh = ss.getSheetByName(SHEET_NAME);
    if (!sh) throw new Error('シート "' + SHEET_NAME + '" が見つかりません。setup() を実行してください。');
    return sh;
  }

  function rowToObject_(row) {
    var o = {};
    for (var i = 0; i < COLUMNS.length; i++) o[COLUMNS[i]] = row[i];
    return o;
  }

  function objectToRow_(obj) {
    return COLUMNS.map(function (k) {
      var v = obj[k];
      return v === undefined || v === null ? '' : v;
    });
  }

  function newId_() {
    // ULID ライクな並び替え可能ID
    var t = Date.now().toString(36);
    var r = Utilities.getUuid().replace(/-/g, '').slice(0, 10);
    return 'c_' + t + '_' + r;
  }

  function nowIso_() { return new Date().toISOString(); }

  function currentUser_() {
    try { return Session.getActiveUser().getEmail() || ''; } catch (e) { return ''; }
  }

  function listAll() {
    var sh = sheet_();
    var last = sh.getLastRow();
    if (last < 2) return [];
    var values = sh.getRange(2, 1, last - 1, COLUMNS.length).getValues();
    return values.map(rowToObject_);
  }

  function findRowIndexById_(id) {
    var sh = sheet_();
    var last = sh.getLastRow();
    if (last < 2) return -1;
    var ids = sh.getRange(2, 1, last - 1, 1).getValues();
    for (var i = 0; i < ids.length; i++) {
      if (ids[i][0] === id) return i + 2; // 1-indexed + header
    }
    return -1;
  }

  function appendOne(card) {
    var sh = sheet_();
    var now = nowIso_();
    var record = Object.assign({}, card, {
      id: card.id || newId_(),
      createdAt: card.createdAt || now,
      updatedAt: now,
      owner: card.owner || currentUser_()
    });
    sh.appendRow(objectToRow_(record));
    return record;
  }

  function appendMany(cards) {
    if (!cards || cards.length === 0) return [];
    var sh = sheet_();
    var now = nowIso_();
    var owner = currentUser_();
    var records = cards.map(function (c) {
      return Object.assign({}, c, {
        id: c.id || newId_(),
        createdAt: c.createdAt || now,
        updatedAt: now,
        owner: c.owner || owner
      });
    });
    var rows = records.map(objectToRow_);
    sh.getRange(sh.getLastRow() + 1, 1, rows.length, COLUMNS.length).setValues(rows);
    return records;
  }

  function update(id, patch) {
    var sh = sheet_();
    var rowIndex = findRowIndexById_(id);
    if (rowIndex < 0) throw new Error('id=' + id + ' が見つかりません');
    var current = rowToObject_(sh.getRange(rowIndex, 1, 1, COLUMNS.length).getValues()[0]);
    // 共有時の編集制限：owner のみ更新可（owner 未記録の旧行は自ユーザーに限定）
    var me = currentUser_();
    if (current.owner && me && current.owner !== me) {
      throw new Error('他ユーザーが登録した名刺は編集できません');
    }
    var updated = Object.assign({}, current, patch, {
      id: current.id,
      createdAt: current.createdAt,
      owner: current.owner || me,
      updatedAt: nowIso_()
    });
    sh.getRange(rowIndex, 1, 1, COLUMNS.length).setValues([objectToRow_(updated)]);
    return updated;
  }

  function remove(id) {
    var sh = sheet_();
    var rowIndex = findRowIndexById_(id);
    if (rowIndex < 0) throw new Error('id=' + id + ' が見つかりません');
    var current = rowToObject_(sh.getRange(rowIndex, 1, 1, COLUMNS.length).getValues()[0]);
    var me = currentUser_();
    if (current.owner && me && current.owner !== me) {
      throw new Error('他ユーザーが登録した名刺は削除できません');
    }
    sh.deleteRow(rowIndex);
    return { id: id };
  }

  return {
    COLUMNS: COLUMNS,
    SHEET_NAME: SHEET_NAME,
    ensureSheets: ensureSheets_,
    listAll: listAll,
    appendOne: appendOne,
    appendMany: appendMany,
    update: update,
    remove: remove,
    _currentUser: currentUser_
  };
})();
