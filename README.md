## Getting started

Create a folder for your project and `cd` into it:

```sh
mkdir myproject
cd myproject
```

Create a [virtualenv](https://docs.python.org/3/library/venv.html) and activate it:

```sh
python3 -m venv env
source env/bin/activate
```

### `compile`

Compile Cairo contracts. Compilation articacts are written into the `artifacts/` directory.

```sh
nile compile # compiles all contracts under contracts/
nile compile contracts/MyContract.cairo # compiles single contract
```

### `deploy`

```sh
nile deploy contract --alias my_contract
🚀 Deploying contract
🌕 artifacts/contract.json successfully deployed to 0x07ec10eb0758f7b1bc5aed0d5b4d30db0ab3c087eba85d60858be46c1a5e4680
📦 Registering deployment as my_contract in localhost.deployments.txt
```
