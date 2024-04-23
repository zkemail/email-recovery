## Module Template

**A template for building smart account modules using the [ModuleKit](https://github.com/rhinestonewtf/modulekit)**

## Usage

### Install dependencies

```shell
pnpm install
```

### Update ModuleKit

```shell
pnpm update rhinestonewtf/modulekit
```

### Building modules

1. Create a new file in `src` and inherit from the appropriate interface (see templates)
2. After you finished writing your module, run the following command:

```shell
forge build
```

### Testing modules

1. Create a new `.t.sol` file in `test` and inherit from the correct testing kit (see templates)
2. After you finished writing your tests, run the following command:

```shell
forge test
```

### Deploying modules

1. Import your modules into the `script/DeployModule.s.sol` file.
2. Create a `.env` file in the root directory based on the `.env.example` file and fill in the variables.
3. Run the following command:

```shell
source .env && forge script script/DeployModule.s.sol:DeployModuleScript --rpc-url $DEPLOYMENT_RPC --broadcast --sender $DEPLOYMENT_SENDER --verify
```

Your module is now deployed to the blockchain and verified on Etherscan.

If the verification fails, you can manually verify it on Etherscan using the following command:

```shell
source .env && forge verify-contract --chain-id [YOUR_CHAIN_ID] --watch --etherscan-api-key $ETHERSCAN_API_KEY [YOUR_MODULE_ADDRESS] src/[PATH_TO_MODULE].sol:[MODULE_CONTRACT_NAME]
```

## Tutorials

For general explainers and guided walkthroughs of building a module, check out our [documentation](https://docs.rhinestone.wtf/modulekit).
