open util/ordering[Time]

// signature
sig Time {}

sig Now{
	now: one Time,
}

sig Job {
	last_run: one Time,
	next_run: one Time,
	writes: lone File
}

sig File{}

// 静的な制約
// nowは必ず１つある
fact OnlyOneNow {
    one Now
}

// １つのnowはただ１つの時間を指す
fact NowOnlyOne{
	all n: Now | one n.now
}


// すべてのjobは、ただ１つの実行中（開始）時間を持つ
fact AtLeastOneExe {
	all j: Job | one j.last_run
}

// すべてのjobは、ただ１つの次に実行可能な時間を持つ
fact OneNextTime{
	all j: Job | one j.next_run
}

// nowはnext_runを超えない
fact NowDoesNotExceedNext {
	all j: Job, n: Now |
		all t: Time | n.now in prevs[t] or n.now = t implies t not in j.next_run
}

// nowはlast_runを超えない
fact NowDoesNotExceedLast {
	all j: Job, n: Now |
		all t: Time | n.now in prevs[t] or n.now = t implies t not in j.last_run
}

// next_runの後には、last_runがtimeに結ばれない
fact NoNextRunAfterExe{
	all j: Job |
		all n: Now | 
			n.now in prevs[j.next_run] or n.now = j.next_run
}
// 同じjobの、last_runとnext_runがかぶることは無い
fact NoDuplicateExe{
	all j: Job | j.next_run not in j.last_run
}

// last_runとnext_runの間隔は1(仮に) 以上
fact IntervalDiff {
	all j: Job |
	j.last_run in prevs[j.next_run]
}

// 検証したい条件
assert NoFileCollision {
	all disj j1, j2: Job |
	// 両方とも書き込むファイルを持っていて、かつ同じファイルなら
	some j1.writes and some j2.writes and j1.writes = j2.writes
	=>
	// 同じ時刻でnext_runは衝突しない
	no t: Time | t in j1.next_run and t in j2.next_run
}


check NoFileCollision for 6 but 6 Job
// run {} for 10 but 4 Job
