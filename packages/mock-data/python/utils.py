import sys
import os
import requests
from dotenv import load_dotenv
from eth_abi import encode
from eth_utils import function_signature_to_4byte_selector
from generate_proof import generate_proofs, get_block
import math

# Time constants
week = 7 * 24 * 60 * 60

# 20th July
#start_timestamp = 1721503200

# 1st January
start_timestamp = 1704067200
start_epoch = math.ceil(start_timestamp / week) * week

# Token constants
ARB = '0x912CE59144191C1204E64559FE8253a0e49E6548'
ARB_AMOUNT = 1000000

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

def set_balance(address, amount, token=None):
    if token is None:
        requests.post(os.getenv("TENDERLY_VIRTUAL_TESTNET_RPC"), json={
        "jsonrpc": "2.0",
        "method": "tenderly_setBalance",
        "params": [[address], hex(amount*10**18)]
        })
        print(f"balance of {address} set to {amount}")
    else:
        requests.post(os.getenv("TENDERLY_VIRTUAL_TESTNET_RPC"), json={
        "jsonrpc": "2.0",
        "method": "tenderly_setErc20Balance",
        "params": [token, address, hex(amount*10**18)]
        })
        print(f"ERC20 balance of {address} set to {amount} (token : {token})")

def function_selector(signature):
    return function_signature_to_4byte_selector(signature).hex()

def encode_params(types, params):
    return encode(types, params).hex()

def get_calldata(function, args, ADDRESSES, default_address=os.getenv("ADDRESS")):
    to_address = ADDRESSES['votemarket']
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
            args.get('manager', default_address),
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

    elif function == 'insertBlockNumber':
        # Define target address and epoch timestamp
        to_address = ADDRESSES['oracle']
        epoch = start_epoch + args['epoch_index'] * week
        # Get block data
        block = get_block(epoch)

        calldata = f"0x{function_selector('insertBlockNumber(uint256,(bytes32,bytes32,uint256,uint256))')}"

        calldata += encode_params([
            'uint256',
            '(bytes32,bytes32,uint256,uint256)'
        ],[
            epoch,
            (
                block["hash"],
                bytes(0),
                block["number"],
                block["timestamp"]
            )
        ])
        print(f"Epoch {args['epoch_index']} : inserted block hash {block['hash'].hex()}")

    elif function == 'update':
        # Define target address
        to_address = ADDRESSES['router']

        # Init multicall calldata
        calldata = f"0x{function_selector('multicall(bytes[])')}"

        # For each epoch
        calldata_list = []
        for i in range(args['firstEpochUpgrade'], args['lastEpochUpgrade']+1):
            # Get epoch timestamp
            epoch = start_epoch + i*week

            # Get proofs
            _, rlp_block, account_proof, rlp_proof = generate_proofs(args['gauge'], epoch, True)
            # Set block data
            set_block_calldata= f"0x{function_selector('setBlockData(address,bytes,bytes)')}"
            set_block_calldata+= encode_params(
                [
                    'address', 
                    'bytes', 
                    'bytes'
                ],[
                    ADDRESSES['verifier'],
                    rlp_block,
                    account_proof
                ])
            calldata_list += [bytes.fromhex(set_block_calldata[2:])]
            # Set gauge data
            set_gauge_calldata= f"0x{function_selector('setPointData(address,address,uint256,bytes)')}"
            set_gauge_calldata+= encode_params(
                [
                    'address', 
                    'address',
                    'uint256', 
                    'bytes'
                ],[
                    ADDRESSES['verifier'],
                    args['gauge'],
                    epoch,
                    rlp_proof
                ])
            calldata_list += [bytes.fromhex(set_gauge_calldata[2:])]

            if i != args['firstEpochUpgrade'] and i != args['lastEpochUpgrade']:
                # Upgrade epoch
                upgrade_calldata = f"0x{function_selector('updateEpoch(address,uint256,uint256,bytes)')}"
                upgrade_calldata+= encode_params([
                    'address',
                    'uint256',
                    'uint256',
                    'bytes'
                ], [
                    ADDRESSES['votemarket'],
                    args['campaignId'],
                    epoch,
                    b''
                ])

                # add all in multicall list
                calldata_list += [bytes.fromhex(upgrade_calldata[2:])]

        calldata += encode_params([
            'bytes[]'
        ], [
            calldata_list
        ])

    else:
        calldata = '0x'

    return to_address, calldata