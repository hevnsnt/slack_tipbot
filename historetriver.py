#!/usr/bin/python
##########################################################
###  SecKCoin History-retriver v0.001                  ###
### /home/seckcoin/bin/retriever.py                    ###
##########################################################

import csv #CSV Library for writing!
import subprocess
from json import loads
from datetime import datetime


def getoutput(command,argument):
        p = subprocess.Popen([command, argument], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = p.communicate()
        out = loads(out)
        return out

def writecsf(infoDict):
        with open('/home/seckcoin/bin/history.csv', 'a') as f:
                w = csv.DictWriter(f, infoDict.keys())
                w.writeheader()
                w.writerow(infoDict)

def main():
        miningInfo = getoutput('/home/seckcoin/bin/seckcoind','getmininginfo')
        generalInfo = getoutput('/home/seckcoin/bin/seckcoind','getinfo')
        seckcoinInfo = generalInfo.copy() # In order to merge dicts that have same keys, copy to new dict
        seckcoinInfo.update(miningInfo) # Then update with other dict (this has priority)
        seckcoinInfo['timestamp'] = datetime.today()
        writecsf(seckcoinInfo)


if __name__ == "__main__":
    # execute only if run as a script
    main()