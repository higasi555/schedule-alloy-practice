# Alloyによる形式検証の実習
学籍番号: 2210593

## 検証対象のOSS
### 概要
今回、pythonで定期的なタスク実行をスケジュールできるライブラリである「schedule」を対象に、プログラムのモデル化による形式検証を行うこととした。
このライブラリはpipで簡単にインストールすることができ、関数ごとに、どのような間隔で実行させるのかを指定することができる。例えば、10秒おきに実行させたければ
```aiignore
schedule.every(10).seconds.do(jobname)
```
などとscheduleに登録を行い、その後
```aiignore
while True:
    schedule.run_pending()
```
のように、schedule内のrunnerを呼び出すことで、指定した関数を一定間隔で動かすことができる。間隔の指定は種々様々にでき、秒分時ごとの指定はもちろん、曜日ごとの指定をすることができる。

### リンク
* 以下が本OSSへのリンクである。<br>
https://github.com/dbader/schedule<br>
* ドキュメントは、以下のリンクからアクセスできる。<br>
https://schedule.readthedocs.io/en/stable/index.html

## 検証すべき性質
### 性質について
次の性質について、検証することとした。
* 「ファイルアクセスが衝突するような異なるjob同士が、同時刻に発生することはない」
  * これは、2つのジョブが同一ファイルを扱う場合は常に排他接続となり、衝突する時間が存在しないはずであるという、安全性として考えることのできる性質である。

### 妥当性
次に、この性質を選んだ理由について説明する。<br>
まず、一般的に、同じファイルに同時に書き込みを行うと、データが壊れたり不具合が発生することがある。授業中の例にもある通り、あるプロセスがファイルをopenしている場合は、そのファイルに対してロックをかけるのが通例である。
そのため、ファイル書き込み時の排他性はどんなソフトウェアでも重要なものとなる。<br>
一方で、本OSSであるscheduleでは並列実行を採用しているとあるが([https://schedule.readthedocs.io/en/stable/parallel-execution.html](https://schedule.readthedocs.io/en/stable/parallel-execution.html))、ジョブ間でファイルアクセスを共有した事象が発生した場合にどう動くかが明確ではない。
そのため、モデル化により、この安全性が満たされるかどうかを検証することとした。

## モデル化
次に、本OSSをどのようにモデル化したかについて説明する。<br>
まず、jobごとに状態遷移を定義することは非常に難解であったため、今回は時間を離散的に扱い、シグネチャとして定義し、ジョブの実行時間やファイルへのアクセスを、相関図的に表現することとした。<br>
### signatureについて
以下は、各シグネチャと元OSSの対応関係である。

* Time
  * 前述の通り離散的な時刻を表すシグネチャで、alloyでデフォルトで使うことのできる`util/ordering[Time]`を利用し、離散的な時間列を生成した。
* Now
  * 現在時刻を表すためのシグネチャで、元OSSでもnow変数として現在時刻が格納されている。
* File
  * jobがアクセスするであろうファイルを表すシグネチャ。
* Job
  * 各job、すなわち実際に実行したい関数を表すシグネチャであり、元OSSでのJobクラスに相当する。実装上は非常に多くの変数を持っているが、ここでは以下の変数を用いて最小限抽象化を行った。
    * last_run: 直近の実行開始時刻。元OSSでのJobクラスのself.last_runに相当する。
    * next_run: 次回の実行予定時刻。元OSSでのJobクラスのself.next_runに相当する。
    * writes: fileへの書き込み関係（これは変数としては格納されていないが、ファイルへのアクセスを表現するために今回用いた）

### factについて
次に、モデルが満たす静的な制約であるfactについて説明する。なお、元OSSでは実行間隔を保存するIntervalという変数があるが、今回それをうまくモデル化することができなかったため、簡易的にIntervalが可変であると仮定し特にモデルに組み込むことなく検証を行った。なお、元OSSでは実際にIntervalを可変にすることができる。(https://schedule.readthedocs.io/en/stable/examples.html)
* fact OnlyOneNow
  * 元OSSで変数nowにただ1つ存在することを表現
* fact NowOnlyOne
  * 元OSSで変数nowにただ1つの時刻が格納されていることを表現
* fact AtLeastOneExe
  * 元OSSですべてのjobは、ただ１つの実行中（開始）時間を持つことを表現
* fact OneNextTime
  * 元OSSですべてのjobは、ただ１つの次に実行可能な時間を持つことを表現
* fact NowDoesNotExceedNex
  * 元OSSでnowはnext_runを超えないことを表現。元OSSではもしnext_runがnowよりも手前の時刻になった場合、next_runがnowを超えるまで無限にIntervalを加算することで、この仕様を実現している。(`__init__.py`の733行目のwhileループ`while next_run <= now:
            next_run += period`)
* fact NowDoesNotExceedLast
  * 元OSSでnowはlast_runを超えないことを表現。これは、元OSSで実行時の時間を記録することから自明である。(`__init__.py`の692行目の`self.last_run = datetime.datetime.now()`)
* fact NoNextRunAfterExe
  * 元OSSで、next_runの後の時間がlast_runに入ることがないことを表現。これも、上2つの制約から自明である。
* fact NoDuplicateExe
  * 元OSSで、同じjobの、last_runとnext_runがかぶることは無いことを表現。これは、元OSSでnext_runはnowにIntervalを追加していることに由来する。(`__init__.py`の`def _schedule_next_run(self)`内、全体で719行目からの処理)
* fact IntervalDiff
  * 元OSSで、last_runとnext_runの間隔がInterval以上であることを表現。前述の通りIntervalを用いたモデル化が難解であったため、今回はその間隔が1以上であれば良いとしている。

元OSSでは以上で表現した変数next_runが現在時刻ど一致するか確認を行い、一致すれば実行するというループを繰り返すことによりスケジューリング処理を実現している。

## 検証手法
以上のようにモデルを設計した上で、前述の「ファイルアクセスが衝突するような異なるjob同士が、同時刻に発生することはない」性質を検証することとした。
これを論理式にすると、次のようになる。
```aiignore
(ファイルアクセスが衝突する)∧(同時刻にjobが実行される)
```
つまり、前述で定義したalloy上の変数を用いると、あるjob 2つ（job1とjob2とする）を取った時、
```aiignore
(job1のwritesとjob2のwritesが示す先が同じ)∧(job1のnext_runとjob2のnext_runが示す先が同じ)
```
となる事象が存在すれば、それは検証する性質を満たさないこととなる。<br>
以上のことを踏まえ、検証事項は次のように定義した。
```aiignore
assert NoFileCollision {
	all disj j1, j2: Job |
	some j1.writes and some j2.writes and j1.writes = j2.writes
	=> no t: Time | t in j1.next_run and t in j2.next_run
}
```


## 補足事項
### 形式検証結果
結果、fileの衝突に関する制約がないことから明らかではあるが、この検証したい性質が満たされていないことが分かった。

### 実際にライブラリを用いての実装検証
#### 手法
今回、本当に検証したい性質が満たされないか確認するために、実際にalloy-practiceディレクトリ内の`test.py`のように実装を行った。
同じファイルへアクセスするjob1とjob2があり、job1とjob2ではファイル書き込み時間が異なるものとした。そして、これらのjobを同時刻に同じintervalを設定して起動した。<br>
実装ではメインスレッドが`run_pending()`でジョブを呼び出すたびに、新しいスレッドがファイル書き込みを行うため、複数スレッドが同時に`testfile.txt`を書き込みするような状況を作った。<br>
もし衝突が起こらないようにブロックしながら実行する仕組みがあれば、テキストファイルの中身は
```aiignore
[Job1] start writing
[Job1] finish writing
[Job2] start writing
[Job2] finish writing
[Job1] start writing
[Job1] finish writing
[Job2] start writing
[Job2] finish writing
...
```
のように、job1の履歴とjob2の履歴が交互に残るはずである。<br>
#### 結果と考察
結果、単一ファイルに複数のjobがアクセスしたまま次のjobが走るということが発生したため、アクセスしたtxtファイルの書き込み内容の行が混ざり、job1とjob2が交互にファイルアクセスしない結果となった。一方で、osのファイルアクセス制御により、同一ファイルに対して同時に書き込みが行われるということは無さそうだということが分かった。<br>
```aiignore
[Job2] start writing
[Job2] finish writing
[Job2] start writing
[Job2] finish writing
[Job2] start writing
[Job2] finish writing
[Job1] start writing
[Job1] finish writing
[Job2] start writing
[Job2] finish writing
...
```

### その他補足事項
alloy-practice内には以下のファイルを配置した。
* alloy-practice-check.als
  * 実際に検証で使用した、alloyのプロジェクトファイル
* test.py
  * 本当に性質が満たされないか、実装上で確認した際のpythonファイル。pipで`schedule`と`pytz`をinstallする必要がある。
* testfile.txt
  * test.pyを動かした時に生成される、同時アクセスを目指すテキストファイル。

なお、元OSSのソースコードは`/schedule/__init__.py`となる。また、今回の検証の本題とは逸れるが、`/test_schedule.py`でunittestを用いた、assert文による検証を行っていることが確認できた。<br>
また、元OSSのソースコードを動かすためには`requirements-dev.txt`をpipでinstallする必要がある。
