import json
import random
import math
import time
import os
import sys
from dotenv import load_dotenv

from eth_abi import encode
from eth_utils import to_checksum_address
from generate_proof import generate_proofs
from web3 import Web3

from utils import (
    set_timestamp, 
    time_jump, 
    set_balance, 
    function_selector, 
    encode_params, 
    get_calldata,
    week,
    start_epoch,
    start_timestamp,
    ARB,
    ARB_AMOUNT
)

# Deployed contracts
ADDRESSES = {
    'votemarket': '0x6c8fc8482fae6fe8cbe66281a4640aa19c4d9c8e',
    'oracle': '0xa20b142c2d52193e9de618dc694eba673410693f',
    'lens': '0xc65973c048fad0327a24c40848991c0fccbd3279',
    'verifier' : '0x348d1bd2a18c9a93eb9ab8e5f55852da3036e225',
    'router' : '0xcE1f6A342A82391da9B15608758703dd9D837ec8'
}

load_dotenv()

def randomTimestamp(epoch):
    return start_epoch + epoch * week + math.floor((random.randint(0, 10000) * week)/10000)

def run_deployment():
    # Print addresses
    print(f"Votemarket address : {ADDRESSES['votemarket']}")
    print(f"Oracle address : {ADDRESSES['oracle']}")
    print(f"Votemarket address : {ADDRESSES['lens']}")
    print(f"Verifier address : {ADDRESSES['verifier']}")
    print(f"Router address : {ADDRESSES['router']}")
    print('--------------------------------------------------------')

    # Setup web3
    tenderly_rpc_url = os.getenv('TENDERLY_VIRTUAL_TESTNET_RPC')
    assert tenderly_rpc_url is not None, "You must set TENDERLY_VIRTUAL_TESTNET_RPC environment variable"
    w3 = Web3(Web3.HTTPProvider(os.getenv('TENDERLY_VIRTUAL_TESTNET_RPC')))

    # Checks for env settings
    private_key = os.getenv("PRIVATE_KEY")
    assert private_key is not None, "You must set PRIVATE_KEY environment variable"
    default_address = os.getenv('ADDRESS')
    assert default_address is not None, "You must set ADDRESS environment variable"

    # Check address nonce for pushing transactions
    nonce = w3.eth.get_transaction_count(default_address)

    # Fork setup, deal gas, token and set strat timestamp of the simulation
    set_balance(default_address, 1000000)
    set_balance(default_address, ARB_AMOUNT, ARB)
    set_timestamp(start_timestamp)

    # Set authorization
    authorize_calldata = f"0x{function_selector('setAuthorizedBlockNumberProvider(address)')}"
    authorize_calldata += encode_params([
        'address'
    ],[
        default_address
    ])
    approve_tx = {
        'from': default_address,
        'to': to_checksum_address(ADDRESSES['oracle']),
        'value': 0,
        'nonce': nonce,
        'gas': 8000000,
        'gasPrice': 15000000,
        'data': authorize_calldata
    }
    signed_approve = w3.eth.account.sign_transaction(approve_tx, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
    nonce+=1
    print(f"Authorize {default_address} to push block data on oracle")

    authorize_calldata = f"0x{function_selector('setAuthorizedBlockNumberProvider(address)')}"
    authorize_calldata += encode_params([
        'address'
    ],[
        ADDRESSES['verifier']
    ])
    approve_tx = {
        'from': default_address,
        'to': to_checksum_address(ADDRESSES['oracle']),
        'value': 0,
        'nonce': nonce,
        'gas': 8000000,
        'gasPrice': 15000000,
        'data': authorize_calldata
    }
    signed_approve = w3.eth.account.sign_transaction(approve_tx, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
    nonce+=1
    print(f"Authorize verifier to push block data on oracle")

    authorize_calldata = f"0x{function_selector('setAuthorizedDataProvider(address)')}"
    authorize_calldata += encode_params([
        'address'
    ],[
        ADDRESSES['verifier']
    ])
    approve_tx = {
        'from': default_address,
        'to': to_checksum_address(ADDRESSES['oracle']),
        'value': 0,
        'nonce': nonce,
        'gas': 8000000,
        'gasPrice': 15000000,
        'data': authorize_calldata
    }
    signed_approve = w3.eth.account.sign_transaction(approve_tx, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
    nonce+=1
    print(f"Authorize verifier to push data on oracle")

    # Approve token to votemarket
    approve_calldata = f"0x{function_selector('approve(address,uint256)')}"
    approve_calldata += encode_params([
        'address',
        'uint256'
    ],[
        ADDRESSES['votemarket'],
        ARB_AMOUNT * 10**18
    ])
    approve_tx = {
        'from': default_address,
        'to': to_checksum_address(ARB),
        'value': 0,
        'nonce': nonce,
        'gas': 8000000,
        'gasPrice': 1500000000,
        'data': approve_calldata,
    }
    signed_approve = w3.eth.account.sign_transaction(approve_tx, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)
    nonce+=1
    print(f"Approved {ARB_AMOUNT} ARB")
    
    # Define absolute path to the input file
    file_dir = os.path.realpath(__file__)
    input_path = os.path.abspath(os.path.realpath(os.path.join(file_dir, '../../json/scenario_input.json')))
    with open(input_path, 'r') as file:
        data = json.load(file)
        # Create all the steps for scenarios and sort them by timestamp
        steps = []
        for scenario in data:
            for step in scenario['steps']:  
                step['timestamp'] = randomTimestamp(step['epoch'])
                steps.append(step)
        steps.sort(key=lambda x: x['timestamp'])

        # Jump to first step timestamp
        time_jump(steps[0]['timestamp'] - start_timestamp)

        # List of all set blocks
        set_epoch_index_block=[]

        # Execute all steps
        for i in range(len(steps)):
            step = steps[i]
            function = step['function']
            args = step['args']

            if function == 'updateAndClose':
                for epoch_index in range(args['firstEpochUpgrade'], args['lastEpochUpgrade']):
                    if epoch_index not in set_epoch_index_block:
                        to_address, calldata = get_calldata('insertBlockNumber', {"epoch_index":epoch_index}, ADDRESSES)
                        transaction = {
                            'from': default_address,
                            'to': to_checksum_address(to_address),
                            'value': 0,
                            'nonce': nonce,
                            'gas': 8000000,
                            'gasPrice': 15000000,
                            'data': calldata
                        }
                        signed = w3.eth.account.sign_transaction(transaction, private_key=private_key)
                        tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
                        nonce += 1
                        set_epoch_index_block.append(epoch_index)
                        print(f"Block data set for epoch {epoch_index}")

            to_address, calldata = get_calldata(function, args, ADDRESSES)

            transaction = {
                'from': default_address,
                'to': to_checksum_address(to_address),
                'value': 0,
                'nonce': nonce,
                'gas': 800000000,
                'gasPrice': 15000000,
                'data': calldata
            }

            signed = w3.eth.account.sign_transaction(transaction, private_key=private_key)
            tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
            nonce += 1
            print(f"Transaction {nonce} ({function}) : {tx_hash.hex()}")

            if i < len(steps) - 1:
                time_diff = steps[i+1]['timestamp'] - steps[i]['timestamp']
                if time_diff > 1000:
                    time_jump(time_diff)
        
        time_jump(math.floor(time.time()) - steps[len(steps)-1]["timestamp"])
        
        print("Script ended")

def test():
    to_address, calldata = get_calldata('updateAndClose', {
        "campaignId": 0,
        "firstEpochUpgrade": 2,
        "lastEpochUpgrade": 5,
        "gauge": "0xF1bb643F953836725c6E48BdD6f1816f871d3E07"
    }, ADDRESSES)
    
    tenderly_rpc_url = os.getenv('TENDERLY_VIRTUAL_TESTNET_RPC')
    assert tenderly_rpc_url is not None, "You must set TENDERLY_VIRTUAL_TESTNET_RPC environment variable"
    w3 = Web3(Web3.HTTPProvider(os.getenv('TENDERLY_VIRTUAL_TESTNET_RPC')))

    # Checks for env settings
    private_key = os.getenv("PRIVATE_KEY")
    assert private_key is not None, "You must set PRIVATE_KEY environment variable"
    default_address = os.getenv('ADDRESS')
    assert default_address is not None, "You must set ADDRESS environment variable"

    # Check address nonce for pushing transactions
    nonce = w3.eth.get_transaction_count(default_address)
    transaction = {
        'from': os.getenv('ADDRESS'),
        'to': to_checksum_address(to_address),
        'value': 0,
        'nonce': nonce,
        'gas': 800000000,
        'gasPrice': 15000000,
        'data': calldata
    }

    signed = w3.eth.account.sign_transaction(transaction, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

if __name__ == "__main__":
    run_deployment()