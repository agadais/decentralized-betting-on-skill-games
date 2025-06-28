# Decentralized Betting on Skill Games

A smart contract platform for skill-based gaming competitions built on Stacks blockchain.

## Features

- Create skill-based games with entry fees
- Join existing games and compete
- Automated prize distribution
- Platform fee collection
- Score submission and verification

## Contract Functions

### Core Functions
- `create-game` - Create a new skill game
- `join-game` - Join an existing game
- `submit-score` - Submit your game score
- `finalize-game` - Finalize game results
- `distribute-prize` - Distribute winnings

### Read-Only Functions  
- `get-game` - Get game information
- `get-player-in-game` - Get player data for a game
- `is-player-in-game` - Check if player is in game

## Usage

1. Deploy contract to Stacks blockchain
2. Create games with specific parameters
3. Players join by paying entry fee
4. Submit scores when game is active
5. Contract owner finalizes and distributes prizes

## Development

```bash
# Install dependencies
npm install

# Run tests
clarinet test

# Check contract
clarinet check