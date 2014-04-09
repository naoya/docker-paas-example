docker-paas-example
===================

boot2docker な Docker に対して、git push 契機でコンテナを作り、Heroku の buildpacks でコンテナ内にWebアプリケーション環境をオンデマンドでビルドして、実際にそこでアプリケーションを立ち上げる･･･ということをやる実装例。

要するに git push するとコンテナでアプリケーションが起動するという、Heroku 的なもの。

Docker Meetup Tokyo #2 に向けて試作した。

結果的には Dokku がやっていることそれと同じになってしまったが、まああくまで結果的なのでそれはよしとする。

仕組み
------

- Dockerfile でイメージをビルドすると、コンテナの元になるイメージが作られる
    - このイメージには、git サーバーへの鍵、buildpacks など最小限のものが入ってる
- `create_repos.rb` で OSX 内に git のリモートレポジトリを作る。`heroku create` に相当
    - create_repos.rb は作ったレポジトリの post-update hooks に docker run で buildpack するスクリプトを配備する
- できたレポジトリを remote ブランチに設定して、git push すると post-update hooks が動く
- buildpack で生成された yaml ファイルを読み取って、対象のアプリケーションを指定の起動方法で exec する

なお、OSX とコンテナの通信は VMWare のホストオンリーアダプタで行う。VMWare 側でインタフェースを追加して、boot2docker の /var/lib/boot2docker/bootlocal.sh に設定しておく

```
ip addr add 192.168.56.100/24 dev eth1
ip link set eth1 up
```

スクリーンショット
------------------

![](http://cdn.bloghackers.net/images/7eb694136429bd029ac27d8ee481c7b67a59f8ca.png)

Sinatra なアプリケーションを push するとコンテナが立ち上がりビルドされて URL が振られてアクセス可能になる。

![](http://cdn.bloghackers.net/images/7b0e01ca708b5f386884c209bdbfe118c6c8e815.png)

docker attach すると、buildpack でコンテナがビルドされる様子がわかる。ruby が入り、bundle exec でモジュールが入る。

参考にしたもの
--------------

- [Dokku](https://github.com/progrium/dokku)
- [Buildstep](https://github.com/progrium/buildstep)
- [Dockerでいみゅーたぶるなんちゃらを試してみる](http://shanon-tech.blogspot.jp/2014/04/docker.html)

注意
----

- 他人が動かすことはほとんど考慮してない。この手のを試しに動かしたい、という場合は Dokku を使いましょう
