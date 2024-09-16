import sys
import os
import requests
from dotenv import load_dotenv
from eth_abi import encode

load_dotenv()

def time_jump(seconds):
    requests.post(os.getenv("TENDERLY_VIRTUAL_TESTNET_RPC"), json={
        "jsonrpc": "2.0",
        "method": "evm_increaseTime",
        "params": [str(hex(int("0x" + seconds, 16)))],
        "id": "1234"
        })
    print("0x" +encode(['bool'], [True]).hex())

if __name__ == "__main__":
    time_jump(sys.argv[1])