# Votemarket

## Python Dependencies

The test suite includes Python scripts for generating proofs. To set up the Python environment:

1. Create a virtual environment (recommended):

```bash
python -m venv venv
source venv/bin/activate
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Create a `.env` file with your Alchemy API key:

```
ALCHEMY_KEY=your_api_key_here
```

Note: The Python scripts are used for testing purposes and require an Alchemy API key when running against mainnet.
