import json
import random
import math
import time
import os
import sys
from dotenv import load_dotenv

from eth_abi import encode
from eth_utils import function_signature_to_4byte_selector
from web3 import Web3
#from solcx import compile_standard, install_solc


from utils import set_timestamp, time_jump

def function_selector(signature):
    return function_signature_to_4byte_selector(signature).hex()

def encode_params(types, params):
    return encode(types, params).hex()

week = 7 * 24 * 60 * 60
start_timestamp = 1714857600
start_block = 20300000
start_epoch = math.ceil(start_timestamp / week) * week

load_dotenv()
#install_solc("0.8.19")

def randomTimestamp(epoch):
    return start_epoch + epoch * week + math.floor((random.randint(0, 10000) * week)/10000)

def updateCallData(campaignId, epoch):
    calldata = f"0x{function_selector('updateEpoch(uint256,uint256,bytes)')}"
    calldata+= encode_params([
        'uint256',
        'uint256',
        'bytes'
    ], [
        campaignId,
        start_epoch + week * epoch,
        b'\x00'
    ])
    return {
        "ID": 1,
        "data": calldata
    }

def run_deployment(voteMarketAddress, oracleAddress):

    w3 = Web3(Web3.HTTPProvider(os.getenv('TENDERLY_VIRTUAL_TESTNET_RPC')))
    private_key = os.getenv("PRIVATE_KEY")
    assert private_key is not None, "You must set PRIVATE_KEY environment variable"
    defaultAddress = os.getenv('ADDRESS')
    nonce = w3.eth.get_transaction_count(defaultAddress)

    file_dir = os.path.realpath(__file__)

    """with open(os.path.abspath(os.path.realpath(os.path.join(file_dir, '../../../votemarket/src/Votemarket.sol'))), "r") as file:
        votemarket_sol_storage_file = file.read()
        
        compiled_sol = compile_standard({
            "language": "Solidity",
            "sources": {"Votemarket.sol": {"content": votemarket_sol_storage_file}},
            "settings": {
                "outputSelection": {"*": {"*": ["abi", "metadata", "evm.bytecode", "evm.bytecode.sourceMap"]}},
            },
        }, solc_version="0.8.19")
    
        bytecode = compiled_sol["contracts"]["Votemarket.sol"]["Votemarket"]["evm"]["bytecode"]["object"]
        abi = json.loads(compiled_sol["contracts"]["Votemarket.sol"]["Votemarket"]["metadata"])["output"]["abi"]

        Votemarket = w3.eth.contract(abi=abi, bytecode=bytecode)
        transaction = Votemarket.constructor().buildTransaction({"chainId": 1,
			"gasPrice": w3.eth.gas_price,
			"from": defaultAddress,
			"nonce": 1,})
        deploymentHash = w3.eth.account.sign_transaction(transaction, private_key=private_key)
        print("Deploying Contract...")
        deploymentReceipt = w3.eth.wait_for_transaction_receipt(deploymentHash)
        print(f"Contract deployed to {deploymentReceipt.contractAddress}")"""

    set_timestamp(start_timestamp)
    input_path = os.path.abspath(os.path.realpath(os.path.join(file_dir, '../../json/scenario_input.json')))
    print(os.path.realpath(__file__))
    with open(input_path, 'r') as file:
        data = json.load(file)
        steps = []
        for scenario in data:
            for step in scenario['steps']:  
                step['timestamp'] = randomTimestamp(step['epoch'])
                steps.append(step)

        steps.sort(key=lambda x: x['timestamp'])
        time_jump(steps[0]['timestamp'] - start_timestamp)
        for i in range(len(steps)):
            step = steps[i]
            function = step['function']
            args = step['args']
            epoch= step['epoch']
            
            if function == 'createCampaign':
                calldata = f"0x{function_selector('createCampaign(uint256,address,address,address,uint8,uint256,uint256,address[],address,bool)')}"
                calldata += encode_params([
                    'uint256',
                    'address',
                    'address',
                    'address',
                    'uint8',
                    'uint256',
                    'uint256',
                    'address[]',
                    'address',
                    'bool'
                ], [
                    args['chainId'],
                    args['gauge'],
                    args.get('manager', defaultAddress),
                    args['rewardToken'],
                    args['numberOfPeriods'],
                    args['maxRewardPerVote'],
                    args['totalRewardAmount'],
                    args['addresses'],
                    args['hook'],
                    args['isWhitelist']
                ])
            elif function == 'claim':
                calldata = f"0x{function_selector('claim(uint256,uint256,bytes,address)')}"
                calldata += encode_params([
                    'uint256',
                    'uint256',
                    'bytes',
                    'address'
                ], [
                    args['campaignId'],
                    args['epoch'],
                    bytes.fromhex(args['hookData'][2:] if args['hookData'].startswith('0x') else args['hookData']),
                    args['account']
                ])
            elif function == 'closeCampaign':
                
                calldata = f"0x{function_selector('closeCampaign(uint256)')}"
                calldata += encode_params([
                    'uint256'
                ], [
                    args['campaignId']
                ])
            else:
                calldata = '0x'
            
            transaction = {
                'from': defaultAddress,
                'to': voteMarketAddress,
                'value': 0,
                'nonce': nonce,
                'data': calldata
            }

            signed = w3.eth.account.sign_transaction(transaction, private_key=private_key)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            print(f"Transaction {nonce} : {tx_hash}")

            if i < len(steps) - 1:
                time_diff = steps[i+1]['timestamp'] - steps[i]['timestamp']
                if time_diff > 1000:
                    time_jump(time_diff)
        
        time_jump(math.floor(time.time()) - steps[len(steps)-1]["timestamp"])
        
        print("Script ended")


if __name__ == "__main__":
    run_deployment(sys.argv[1], sys.argv[2])