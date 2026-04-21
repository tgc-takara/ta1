/**
 * Gemini を使った OCR / 名刺情報抽出。
 * - extractFromVideo(videoFileId): Gemini File API 経由で動画を投入し、検出された名刺配列を返す
 * - extractFromImage(imageDataUrl): 画像1枚用。inlineData で呼び出し、1件のフィールドを返す
 */
var CardOcr = (function () {
  var BASE = 'https://generativelanguage.googleapis.com';

  function apiKey_() { return Config.geminiApiKey(); }
  function model_() { return Config.geminiModel(); }

  var CARD_FIELDS = {
    type: 'object',
    properties: {
      representativeTimeSec: { type: 'number' },
      '氏名': { type: 'string' },
      'ふりがな': { type: 'string' },
      '会社名': { type: 'string' },
      '部署': { type: 'string' },
      '役職': { type: 'string' },
      'Email': { type: 'string' },
      '電話': { type: 'string' },
      '携帯': { type: 'string' },
      'FAX': { type: 'string' },
      '郵便番号': { type: 'string' },
      '住所': { type: 'string' },
      'URL': { type: 'string' },
      'Twitter': { type: 'string' },
      'LinkedIn': { type: 'string' },
      'Facebook': { type: 'string' },
      'Instagram': { type: 'string' },
      'suggestedTags': { type: 'array', items: { type: 'string' } }
    }
  };

  var VIDEO_SCHEMA = {
    type: 'object',
    properties: { cards: { type: 'array', items: CARD_FIELDS } }
  };

  var BASE_PROMPT =
    'あなたは名刺画像の情報抽出アシスタントです。\n' +
    '名刺に書かれた情報を指定の JSON スキーマに従って抽出してください。\n' +
    '制約:\n' +
    '- 読み取れない項目は空文字 "" にしてください。推測で埋めないでください。\n' +
    '- 電話/携帯/FAX は元の表記のまま（ハイフン含む）。\n' +
    '- Email は @ を含む形のみ。\n' +
    '- URL はスキーム省略があれば "https://" を付けてください。\n' +
    '- SNS は URL か @handle のまま。\n' +
    '- suggestedTags は業界・肩書・イベントから推測できる短い日本語タグを最大3つまで。\n';

  var VIDEO_PROMPT = BASE_PROMPT +
    '\nこの動画には複数の名刺が順番に映っています。\n' +
    '- 画面に映る名刺ごとに cards 配列に1要素出力してください。\n' +
    '- 同じ名刺が複数フレームに映る場合は1つに統合してください（時刻が最も鮮明な瞬間を representativeTimeSec に秒単位で入れる）。\n' +
    '- 手ブレやピンぼけの瞬間は避け、正対したフレームの時刻を選んでください。\n' +
    '- 名刺以外（手・机・ケース）は無視。\n';

  var IMAGE_PROMPT = BASE_PROMPT +
    '\nこの画像は1枚の名刺です。representativeTimeSec は 0 にしてください。\n';

  function generateContent_(payload) {
    var url = BASE + '/v1beta/models/' + encodeURIComponent(model_()) +
      ':generateContent?key=' + encodeURIComponent(apiKey_());
    var attempt = 0;
    while (true) {
      var res = UrlFetchApp.fetch(url, {
        method: 'post',
        contentType: 'application/json',
        muteHttpExceptions: true,
        payload: JSON.stringify(payload)
      });
      var code = res.getResponseCode();
      if (code < 300) return JSON.parse(res.getContentText());
      if (code >= 500 && attempt === 0) {
        attempt++;
        Utilities.sleep(2000);
        continue;
      }
      throw new Error('Gemini generateContent 失敗: ' + code + ' ' + res.getContentText());
    }
  }

  function parseJsonFromResponse_(resp) {
    if (!resp.candidates || !resp.candidates.length) throw new Error('Gemini 応答に candidates がありません');
    var parts = resp.candidates[0].content && resp.candidates[0].content.parts;
    if (!parts || !parts.length) throw new Error('Gemini 応答に parts がありません');
    var text = parts.map(function (p) { return p.text || ''; }).join('');
    try {
      return JSON.parse(text);
    } catch (e) {
      throw new Error('Gemini 応答の JSON パース失敗: ' + text.slice(0, 500));
    }
  }

  function extractFromVideo(videoFileId) {
    var uploaded = GeminiFiles.uploadFromDrive(videoFileId);
    try {
      var payload = {
        contents: [{
          role: 'user',
          parts: [
            { text: VIDEO_PROMPT },
            { fileData: { mimeType: uploaded.mimeType, fileUri: uploaded.uri } }
          ]
        }],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: VIDEO_SCHEMA,
          temperature: 0.1
        }
      };
      var resp = generateContent_(payload);
      var parsed = parseJsonFromResponse_(resp);
      var cards = (parsed && parsed.cards) || [];
      cards.forEach(function (c) { c.sourceVideoFileId = videoFileId; });
      return cards;
    } finally {
      GeminiFiles.deleteFile(uploaded.name);
    }
  }

  function extractFromImage(imageDataUrl) {
    var idx = imageDataUrl.indexOf(',');
    if (idx < 0) throw new Error('不正な画像 dataURL');
    var meta = imageDataUrl.substring(5, idx);
    var semi = meta.indexOf(';');
    var mimeType = semi >= 0 ? meta.substring(0, semi) : meta;
    var b64 = imageDataUrl.substring(idx + 1);
    var payload = {
      contents: [{
        role: 'user',
        parts: [
          { text: IMAGE_PROMPT },
          { inlineData: { mimeType: mimeType, data: b64 } }
        ]
      }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: CARD_FIELDS,
        temperature: 0.1
      }
    };
    var resp = generateContent_(payload);
    return parseJsonFromResponse_(resp);
  }

  return {
    extractFromVideo: extractFromVideo,
    extractFromImage: extractFromImage
  };
})();
