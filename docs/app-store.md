# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.005 |
| アプリ名 | 手習い帖 - 読めるのに書けない漢字（ホーム画面の表示名は「手習い帖」） |
| サブタイトル | 指で書いて、お手本と見比べる稽古帖 |
| カテゴリ | 教育（主）・辞書／辞典／その他（副） |
| サポート URL | https://github.com/enludus-daily/app-20261107-tenarai/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261107-tenarai/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の見込み（暴力・性的・ギャンブル・ホラー・医療・Web 閲覧・ユーザー生成コンテンツの共有・生成 AI なし）。語に「嫉妬」「怨」などの感情語はあるが表現上の問題はない → 4+。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（暗号を使わない） |
| App 内課金 | com.enludus.daily.005.pro（買い切り ¥480・ファミリー共有）。審査用の画像 `docs/iap/paywall.png`。初回はバージョンと一緒に審査に出す（本人） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・壁紙・単純なタイマー・占い・出会いではない。学習（書き取り）で、手で用意した 363 語の例文・間隔をあけた復習・自分の筆跡の帖という中身がある
- 4.3(a) 焼き直し：これまでの enludus-daily のアプリ（英語ドリル・自分実験・句帳・作り置き）と題材・画面・部品（升目・半紙・はなまる・和綴じ）が違う。前のアプリの Theme・部品は使っていない
- 既存のアプリとの意味のある違い：自動の判定をせず、自分の字の上にお手本を重ねて見比べる。書いた字が筆跡のまま帖に残る。Duo の見開き
- 長く使える価値（4.2）：書けなかった字が 1〜60 日の間隔で戻る復習、稽古の暦、書ける字の積み上げ
- 他社の名前・商標・見た目：「漢検」はキーワードにだけ入れた一般の語（説明文では使っていない）。気になるなら本人が外す。ほかの商標・見た目は使っていない
- Apple Intelligence：使わない
- 課金（3.1.1）：StoreKit の非消耗型、購入を復元あり、値段は displayPrice

## 収益の道筋

- 買い切りの Pro ¥480（README の「課金」に比べた表と理由）。広告なし

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない。書いた線・丸・暦は UserDefaults と Application Support のファイルに端末の中だけで保存。解析・広告 SDK なし。通知は端末の中の予約。購入は StoreKit が扱い、開発者は受け取らない）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1。ファイルの日時・容量などの API は使わない）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）：launch（今日の稽古の表紙）・onboarding・practice（書く）・answer（お手本を重ねる）・done（今日の一枚）・notebook（手習い帖）・word・weak・empty・paywall・settings。

## 本人がすること

- [ ] App プライバシーを申告する（API がない。「データの収集なし」）
- [ ] 年齢区分を答える（すべて「なし」の見込み）
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）。サンドボックスで Pro の購入と復元
- [ ] スクリーンショットを確かめる
- [ ] App 内課金をバージョンと一緒に審査に出す・Paid Apps Agreement の確認
- [ ] 審査に提出する
