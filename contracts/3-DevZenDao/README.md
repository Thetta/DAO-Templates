 # DevZenDao
 ---
 ## Description
 This is the DAO for russian most famous "for hard-core developers only" podcast. 
 I was a guest of show #198 (July 30, 2018)
 We discussed how Thetta can be applied to their structure. You can read the blog post here - TODO.
## Requirements
1) Any listener can get a ERC20 “devzen” tokens by sending X ETHers to the DevZen DAO and becomes a “patron” (i.e. token holder).
2) Any patron can use DevZen tokens to run ads: Burn k tokens to add your add into the slot (linear, no priority).
3) Any team member can use Reputation to govern the DAO, i.e., change the parameters. Also, reputation is used in the votes to select the next host and to add or remove moderator.
4) To become a guest, a listener has to become a patron first (i.e., they have to buy some DevZen tokens), then they must stake S tokens for D days. After the show has ended, S tokens are returned to the patron. If the guest missed the show (that is bad), the tokens are burned.   
## Token model (example)
DevZen tokens are minted each week:
 - 10 tokens for 5 ads slots
 - 0 free floating tokens

DevZen tokens are burned:
 - 2 tokens per 1 ads slot (if ads is running in the current episode)

Reputation tokens are minted each week:
- 2 tokens as reputation incentive for 1 host   
- 2 tokens as reputation incentive for 4 moderators
- 1 tokens as incentive for 1 guest