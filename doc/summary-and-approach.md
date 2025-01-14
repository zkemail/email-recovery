# Summary

- When a user would send a account recovery request to a relayer, the relayer will validate whether the account recovery request is correct by sending the following two type of proofs to the following respective Verifier smart contracts:
  - a Email proof would be sent to the **Email Verifier** smart contract. (This is the existing implementation)
  - a EOA proof, which prove a given `EOA` address is correspond to a given `guardian` address, would be sent to the **EOA (guardian) Verifier** smart contract. (This is the new implementation this time by myself)

<br>

# Approach

Here is the overview (workflow) of my approach:

- 1/ A user (`account` owner) would generate a EOA `proof`, which is associated the given `EOA` address with the `guardian` address, by sending both the `EOA` address and the `guardian` address to a prover.

- 2/ A user (`account` owner) would create a request of adding new `guardian` via the GuardianManager#`addGuardian()`.

- 3/ After the request of adding new guardian is created via the GuardianManager#`addGuardian()`, a user (`account` owner) would call the EmailRecoveryManager#`acceptGuardianWithEoa()` with a `proof`, which is associated the `EOA` (user's `account`) address with the `guardian`, in order to accept the request of adding new guardian.
  - At this point, the EOA `proof` and `guardian` address and `EOA` address would be associated and stored into the `proofAssociatedWithGuardians` storage.

- 4/ The user (`account` owner) would call the EmailRecoveryManager#`processRecoveryWithEoaAuth()` to create an account recovery request. At this point, the EmailRecoveryManager contract would send the two type of proofs to respective Verifer smart contract in the EmailRecoveryManager#`processRecoveryWithEoaAuth()` in order to verify the following two type of proofs:
  - `Email proof` is sent to the **Email Verifier** smart contract. (This is the existing implementation)
  - `EOA proof` is sent to the **EOA (guardian) Verifier** smart contract.  (This is the new implementation this time by myself)

- 5/ If the both of the response (of the step 4/) in the EmailRecoveryManager#`processRecoveryWithEoaAuth()` is **true**, the account will be recovered.

<br>

## Integration with the [`EOA-TX-buider`]() (and Email-TX-buider)

- The **Ether EOA-auth SDK (EOA TX Buider)** would be assumed that it work with the [**Ether Email-auth SDK (Email TX Builder)**](https://github.com/zkemail/email-tx-builder) in the [**ZK Email Recovery**](https://github.com/zkemail/email-recovery)
   
   - The architecture of the proof generation with the **Email-auth** (which generate and verify a `Email proof`)and **EOA-auth** (which generate and verify a `EOA proof`)
      ![architecture_proof-generation_with_Email-Auth_and_EOA-auth](https://github.com/user-attachments/assets/ce1f6ec1-3f7f-41e0-a275-8e6668caf3e0)

   - The architecture of the account recovery flow including both the **Email-auth** (which generate and verify a `Email proof`)and **EOA-auth** (which generate and verify a `EOA proof`)
     ![architecture_of_account-recovery-flow_including_EOA-auth](https://github.com/user-attachments/assets/665ad240-0971-4db6-8c7c-4ca6325ef31f)

<br>

## Installation

- 1/ Install modules
```shell
pnpm install
```
or
```shell
forge install
```

- 2/ Compile smart contracts
```shell
pnpm build
```
or
```shell
forge build
```

- 3/ Run the test (NOTE: Running the test file, which is called the `processRecoveryWithEoaAuth.t.sol`)
```shell
forge test -vv --match-contract EmailRecoveryManager_processRecoveryWithEoaAuth_Test
```



<br>

## References
- EOA-auth SDK (`EOA-TX-builder`)：https://github.com/masaun/eoa-tx-builder/tree/develop
- Email-auth SDK (`email-tx-builder`)：https://github.com/zkemail/email-tx-builder