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
        "params": [str(hex(seconds))]
        })
    print(f"Time jumped by {seconds} seconds")

def set_timestamp(timestamp):
    requests.post(os.getenv("TENDERLY_VIRTUAL_TESTNET_RPC"), json={
        "jsonrpc": "2.0",
        "method": "evm_setNextBlockTimestamp",
        "params": [str(timestamp)]
        })
    print(f"timestamp set to {timestamp}")

def set_balance(address, amount, token=''):
    if len(address) == 0:
        requests.post(os.getenv("TENDERLY_VIRTUAL_TESTNET_RPC"), json={
        "jsonrpc": "2.0",
        "method": "tenderly_setBalance",
        "params": [[address], hex(amount*10**18)]
        })
    else:
        requests.post(os.getenv("TENDERLY_VIRTUAL_TESTNET_RPC"), json={
        "jsonrpc": "2.0",
        "method": "tenderly_setErc20Balance",
        "params": [token, address, hex(amount*10**18)]
        })