import sys, rlp, os

from web3 import Web3
from eth_abi import encode
from eth_utils import keccak
from hexbytes import HexBytes
from dotenv import load_dotenv
import requests

load_dotenv()

# Alchemy
RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/" + os.getenv("ALCHEMY_KEY")
GAUGE_CONTROLLER = '0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB'

web3 = Web3(Web3.HTTPProvider(RPC_URL))

BLOCK_HEADER = (
    "parentHash",
    "sha3Uncles",
    "miner",
    "stateRoot",
    "transactionsRoot",
    "receiptsRoot",
    "logsBloom",
    "difficulty",
    "number",
    "gasLimit",
    "gasUsed",
    "timestamp",
    "extraData",
    "mixHash",
    "nonce",
    "baseFeePerGas",
    "withdrawalsRoot",
    "blobGasUsed",
    "excessBlobGas",
    "parentBeaconBlockRoot",
)

def get_block(timestamp):
    block_req = requests.get(f"https://api.etherscan.io/api?module=block&action=getblocknobytime&timestamp={timestamp}&closest=after&apikey={os.getenv('ETHERSCAN_KEY')}")
    block_number = int(block_req.json()["result"]) + 1000
    return web3.eth.get_block(block_number)

"""
    Generate a proof to be pushed into the verifier
    if the proof is about the gauge, the account field isn't needed
"""
def generate_proofs(gauge, timestamp, is_gauge, account=''):
    # Get block data
    block = get_block(timestamp)

    # Encode RLP block
    rlp_block = encode_rlp_block(block)

    # Encode proof
    proof = int.from_bytes(keccak(
        encode(['bytes32'], [
        keccak(
            encode([
                'bytes32',
                'uint256' if is_gauge else 'address'
            ],[
               keccak(
                   encode([
                       'uint256',
                       'address'
                   ],
                   [
                       12 if is_gauge else 11,
                       gauge if is_gauge else account
                   ])
               ),
               timestamp if is_gauge else gauge 
            ])
        )])
    ),"big")
    proofs = [proof]

    # Encode RLP proofs
    account_proof, rlp_proof = encode_rlp_proofs(
        web3.eth.get_proof(GAUGE_CONTROLLER, proofs, block_identifier=int(block["number"]))
    )

    return block["hash"], rlp_block, account_proof, rlp_proof


def encode_rlp_block(block):
    block_header = [
        (
            HexBytes("0x")
            if isinstance((block[k]), int) and block[k] == 0
            else HexBytes(block[k])
        )
        for k in BLOCK_HEADER
        if k in block
    ]
    return rlp.encode(block_header)


def encode_rlp_proofs(proofs):
    account_proof = list(map(rlp.decode, map(HexBytes, proofs["accountProof"])))
    storage_proofs = [
        list(map(rlp.decode, map(HexBytes, proof["proof"])))
        for proof in proofs["storageProof"]
    ]
    return rlp.encode(account_proof), rlp.encode(storage_proofs)
