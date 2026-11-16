# typegap

typegap は、Ruby プロジェクトの RBS の型とコードが食い違っている場所を見つけます。

Steep は型を破るコードを報告します。
typegap は、型から見て要らない、ありえない、使い方を誤りやすいコードを報告します。
たとえば、型が nil にならないと言っている値への `&.`、union の一部を取りこぼした `case`、比べられない要素の `sort` です。
どのルールも [typescript-eslint](https://typescript-eslint.io/rules/) の型を使うルールを移したもので、型は自分で推論せず Steep が推論したものを読みます。

RBS で型を書いたコードでは、見つかるものの多くは死んだコードではなく、型とコードのすき間です。
`x` が nil にならない型なので `x&.name` が報告されたとき、要らないのが `&.` なのか、型が言いすぎなのかは分かりません。
どちらを直すかは読む人が決めます。

## はじめかた

Steep で型検査しているプロジェクトに typegap を足します。

```ruby
# Gemfile
gem "typegap", require: false
```

`Steepfile` のある場所で動かします。

```console
$ bundle exec typegap
lib/shop.rb:28:5: UnnecessarySafeNavigation: `name` is `::String`, never nil, so `&.` is not needed
lib/shop.rb:43:5: CaseExhaustiveness: `status` is `(:open | :closed)`, but no `when` handles `:closed` and there is no `else`
lib/shop.rb:52:5: SortWithoutComparable: `::Point` has only Object#<=>, so `sort` raises ArgumentError. Pass a block or `sort_by`
3 findings
```

すき間が見つかると終了コード 1、なければ 0、動かせないときは 2 で終わります。
CI では `steep check` のあとに動かせます。

```console
$ bundle exec typegap --json            # 1 件ずつ JSON で出す
$ bundle exec typegap lib/shop.rb       # この Ruby ファイルだけ見る(シグネチャのファイルは見ない)
$ bundle exec typegap --only CaseExhaustiveness,SortWithoutComparable
$ bundle exec typegap --except UnusedResult
$ bundle exec typegap --rules           # 全ルールと、元にした typescript-eslint のルール
```

## ルール

ルールの一覧は [README.md](README.md#rules) の表にあります。
UntypedCall だけは既定で止めています。
多くのプロジェクトでは件数が多すぎて一覧として読めないので、型がどこで途切れているかを見たいときに `--only UntypedCall` で動かします。

## typegap が信じないもの

RBS の core は、nil を返すことがあるのに nil にならない型をつけているメソッドがあります。
たとえば、ない鍵を引いた `Hash#[]` や、空の配列の `Array#first` です。
インスタンス変数も、代入される前は型にかかわらず nil です。
ここで型を信じると、コードを守っている nil の確かめを報告してしまうので、typegap はこれらの値については何も言いません。
`untyped`、型変数、`self`、Steep が展開しなかった別名についても何も言いません。

## 必要なもの

Ruby 3.3 以降と Steep 2.1 です。
typegap は公開 API ではない Steep の型検査サービスを読むので、typegap の各バージョンは Steep のマイナーバージョンを 1 つだけ受け付けます。

## ライセンス

MIT です。[LICENSE](LICENSE) を見てください。
