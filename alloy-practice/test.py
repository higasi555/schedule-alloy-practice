import schedule
import time
import threading

def job1():
    def worker():
        with open('testfile.txt', 'a') as f:
            print("job1 started")
            f.write("[Job1] start writing\n")
            time.sleep(8)  # 疑似書き込み時間
            f.write("[Job1] finish writing\n")
            print("job1 finished")
    # 新しいスレッドを立てて実行
    threading.Thread(target=worker).start()

def job2():
    def worker():
        with open('testfile.txt', 'a') as f:
            print("job2 started")
            f.write("[Job2] start writing\n")
            time.sleep(5)
            f.write("[Job2] finish writing\n")
            print("job2 finished")
    threading.Thread(target=worker).start()

# 1秒ごとにjobを行う
schedule.every(1).seconds.do(job1)
schedule.every(1).seconds.do(job2)

while True:
    schedule.run_pending()
    time.sleep(1)
    print("loop now")