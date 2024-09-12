import json
import random
import math
from eth_abi import encode
from eth_utils import function_signature_to_4byte_selector

def function_selector(signature):
    return function_signature_to_4byte_selector(signature).hex()

def encode_params(types, params):
    return encode(types, params).hex()

week = 7 * 24 * 60 * 60
start_epoch = 1714857600

def randomTimestamp(epoch):
    return start_epoch + epoch * week + math.floor((random.randint(0, 10000) * week)/10000)

def build_steps():

    with open('packages/mock-data/json/scenario_input.json', 'r') as file:
        data = json.load(file)
        steps = []
        for scenario in data:
            for step in scenario['steps']:  
                step['timestamp'] = randomTimestamp(step['epoch'])
                steps.append(step)

        steps.sort(key=lambda x: x['timestamp'])
        steps_with_time_jumps = []
        for i in range(len(steps)):
            step = steps[i]
            function = step['function']
            args = step['args']
            
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
                    args.get('manager', '0x0000000000000000000000000000000000000000'),
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

        print(steps_with_time_jumps) 
        
        output_file = 'packages/mock-data/json/scenario_output.json'
        with open(output_file, 'w') as outfile:
            json.dump(steps_with_time_jumps, outfile, indent=2)
        
        print(f"Steps with time jumps have been written to {output_file}")


if __name__ == "__main__":
    build_steps()