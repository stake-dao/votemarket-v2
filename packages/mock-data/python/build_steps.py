import json
import random
import math
import time
import os
from dotenv import load_dotenv

from eth_abi import encode
from eth_utils import function_signature_to_4byte_selector

def function_selector(signature):
    return function_signature_to_4byte_selector(signature).hex()

def encode_params(types, params):
    return encode(types, params).hex()

week = 7 * 24 * 60 * 60
start_timestamp = math.ceil(time.time()) #1714857600
start_block = 20300000
start_epoch = math.ceil(start_timestamp / week) * week

load_dotenv()

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

def build_steps():

    with open('/Users/lucas/Desktop/votemarket-v2/packages/mock-data/json/scenario_input.json', 'r') as file:
        data = json.load(file)
        steps = []
        for scenario in data:
            for step in scenario['steps']:  
                step['timestamp'] = randomTimestamp(step['epoch'])
                steps.append(step)

        steps.sort(key=lambda x: x['timestamp'])
        steps_with_time_jumps = [{
                        "ID": 3,
                        "data": (steps[0]['timestamp'] - start_timestamp).to_bytes(32, byteorder='big').hex()
                    }]
        defaultAddress = os.getenv('ADDRESS')
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
                steps_with_time_jumps.append(updateCallData(args["campaignId"], epoch))
                calldata = f"0x{function_selector('closeCampaign(uint256)')}"
                calldata += encode_params([
                    'uint256'
                ], [
                    args['campaignId']
                ])
            else:
                calldata = '0x'
            
            steps_with_time_jumps.append({
                "ID": 1,
                "data": calldata
            })
            if i < len(steps) - 1:
                time_diff = steps[i+1]['timestamp'] - steps[i]['timestamp']
                if time_diff > 1000:
                    steps_with_time_jumps.append({
                        "ID": 3,
                        "data": time_diff.to_bytes(32, byteorder='big').hex()
                    })
        
        """steps_with_time_jumps.append({
            "ID": 3,
            "data": (math.floor(time.time()) - steps[len(steps)-1]["timestamp"]).to_bytes(32, byteorder='big').hex()
        })"""
        
        output_file = '/Users/lucas/Desktop/votemarket-v2/packages/mock-data/json/scenario_output.json'
        with open(output_file, 'w') as outfile:
            json.dump(steps_with_time_jumps, outfile, indent=2)
        
        print(f"Steps with time jumps have been written to {output_file}")


if __name__ == "__main__":
    build_steps()