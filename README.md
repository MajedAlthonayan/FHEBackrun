# FHEBackrun

Backrunning Private Transactions using fhEVM

# Abstract

Blockchains function by creating blocks of transactions that are executed in order, the ability to alter this order of transactions leads to the extraction of additional value, commonly referred to as Maximal Extractable Value (MEV). MEV is the value extracted from the inserting, removing and the re-ordering of transactions in a block, and this has led to an industry which extracted $750 million worth of MEV before the merge (Flashbots transparency dashboard). Although certain forms of MEV (frontrunning and sandwiching) are universally considered to have negative effects on users and their experience, other forms of MEV (arbitrage and liquidations) are believed to have a positive effect on the user experience by regulating and servicing the markets. In this paper, we expand on the work done by flashbots by utilising fully homomorphic encryption to allow the backrunning of private transactions by searchers whilst also building upon the challenges faced by the previous work in order to reduce the computational overhead as well as expand the possible use cases of our solution.
