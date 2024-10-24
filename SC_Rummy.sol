// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 * @title SC_Rummy 
 * @dev Operating Rummy Game
 */

 /*
    LIST OF REVERT REASONS:
    ----------------------------------------------------------------------------------------------
    RR1: Only the dealer can perform this action.
    RR2: The player is not registered yet!
    RR3: The player is already registered!
    RR4: The player must have a non-zero stake!
    RR5: The player doesn't have sufficient balance to play!
    RR6: The player has not yet shown interest in playing!
    RR7: Time limit exceeded!
    RR8: The dealer must maintain a minimum stake amount to operate the game!
    RR9: Invalid GameID!
    RR10: The game has already been aborted!
    RR11: Invalid PlayerID!
    RR12: The dealer has not yet committed the seed value!
    RR13: You have already revealed your seed!
    RR14: Seed value doesn't match its commitment!
    RR15: Player 1 has not yet revealed the seed!
    RR16: Player 2 has not yet revealed the seed!
    RR17: Initial hash value has not yet been computed!
    RR18: The dealer has not yet committed the players' encrypted hand or MR of the closed deck!
    RR19: You have already provided your consent!
    RR20: After receiving the cards, you have not yet provided your consent!
    RR21: You have already committed the seed_prime used for drawing a card!
    RR22: It's not your turn!
    RR23: Invalid player's turn!
    RR24: The player has not requested to draw a card from the closed deck!
    RR25: The card has already been served!
    RR26: The dealer has not yet provided the card!
    RR27: The player has already committed the received card!
    RR28: The player has not committed the received card yet!
    RR29: Players must discard cards alternately!
    RR30: Incorrect Winner ID!
    RR31: Insufficient stake!
    ----------------------------------------------------------------------------------------------
 */

contract SC_Rummy 
{
    struct Player
    {
        uint256 playerID;
        uint256 currentStake;
        uint256 timestampRegistration;
    }
    mapping(address => Player) public getPlayerDetails;
    mapping(uint256 => address) public getPlayerAddr;

    uint256 public playerIDGenerator;
    address public dealer;
    uint256 public dealerStake;
    uint256 public minimumAmount;
    uint256 public timelimit;

    struct Game
    {
        uint256 gameID;
        bool isGameAborted;
        uint256 p1;
        uint256 p2;
        bytes32 commit_s1;
        uint256 s1;
        uint256 timestamp_reveal_s1;
        bytes32 commit_s2;
        uint256 s2;
        uint256 timestamp_reveal_s2;
        bytes32 commit_sd;
        uint256 timestamp_commit_sd;
        bytes32 initial_hash;
        uint256 timestamp_computing_initial_hash;
        bytes32 commit_p1_encrypted_hand;
        bytes32 commit_p2_encrypted_hand;
        bytes32 commit_MR_closed_deck;
        uint256 timestamp_commit_players_encrypted_hand_and_MR_closed_deck;
        bool consent1;
        uint256 timestamp_consent1;
        bool consent2;
        uint256 timestamp_consent2;
        bytes32 commit_s1_prime;
        uint256 timestamp_commit_s1_prime;
        bytes32 commit_s2_prime;
        uint256 timestamp_commit_s2_prime;
        //For Closed Deck..
        uint256[78] requestedBy;
        uint256[78] timestamp_of_request;
        bytes32[78] encryptedCard;
        bytes32[78] commit_card_by_dealer;
        uint256[78] timestamp_commit_card_by_dealer;
        bytes32[78] commit_card_by_player;
        uint256[78] timestamp_commit_card_by_player;
        uint256 closedDeckCardCounter;
        //For Open Deck..
        uint256[78] putBy;
        uint256[78] discardedCardID;
        uint256[78] timestamp_put_card_on_open_deck;
        uint256 openDeckCardCounter;

        uint256 which_player_turn;

        uint256 winnerID;
        uint256 winningAmount;
        uint256 timestamp_reward;

    }

    uint256 gameIDGenerator;
    mapping(uint256 => Game) gameDetails;
    
    struct InterestedPlayer
    {
        bytes32 commit_s;
        uint256 timestamp_commit;     
    }
    mapping(uint256 => InterestedPlayer) public interestedPlayers;

    // Modifier to ensure only the dealer can perform certain actions
    modifier onlyDealer() {
        require(msg.sender == dealer, "RR1");
        _;
    }

    // Modifier to check if a player is registered
    modifier onlyRegisteredPlayer() {
        require(getPlayerDetails[msg.sender].playerID != 0, "RR2");
        _;
    }
    
    event notifyDealerAboutInterestedPlayer(uint256 playerID, address dealerAddr);
    event notifyPlayerAboutGameID(uint256 p1, uint256 p2, uint256 gameID);
    event notifyDealerToSendClosedDeckCard(uint256 gameID, uint256 playerID, address dealerAddr);

    // Constructor to initialize the contract with the dealer and set up initial parameters
    constructor() payable {
        dealer = msg.sender;
        dealerStake = msg.value;
        playerIDGenerator = 0;
        gameIDGenerator = 0;
        minimumAmount = 1000;
        timelimit = 500;
    }
    
    // Registers a new player by assigning a playerID
    function playerRegistration() external payable {
        Player memory p = getPlayerDetails[msg.sender];
        require(p.playerID == 0, "RR3");
        require(msg.value != 0, "RR4");
        playerIDGenerator ++;
        p.playerID = playerIDGenerator;
        p.currentStake = msg.value;
        p.timestampRegistration = block.timestamp;
        getPlayerDetails[msg.sender] = p;
    }

    // Allows a registered player to express interest in playing by committing a seed value
    function willingToPlay(bytes32 _commitSeed) external onlyRegisteredPlayer{
        Player memory p = getPlayerDetails[msg.sender];
        require(p.currentStake >= minimumAmount, "RR5");
        interestedPlayers[p.playerID] = InterestedPlayer(_commitSeed, block.timestamp);
        emit notifyDealerAboutInterestedPlayer(p.playerID, dealer);
    }
    
    // Internal function to verify if a player is interested in playing
    function checkIfPlayerInterested(uint256 _pID) internal view {
        require(interestedPlayers[_pID].timestamp_commit != 0, "RR6");
        require( (block.timestamp - interestedPlayers[_pID].timestamp_commit) <= timelimit, "RR7");
    }

    // Allows the dealer to create a new game between two players and commits the dealer’s seed
    function createGame(uint256 _p1ID, uint256 _p2ID, bytes32 _commitDealerSeed) external onlyDealer{
        require(dealerStake >= minimumAmount, "RR8");
        checkIfPlayerInterested(_p1ID);
        checkIfPlayerInterested(_p2ID);
        gameIDGenerator ++;
        Game memory newGame = gameDetails[gameIDGenerator];
        newGame.gameID = gameIDGenerator;
        newGame.isGameAborted = false;
        newGame.p1 = _p1ID;
        newGame.p2 = _p2ID;
        newGame.commit_s1 = interestedPlayers[_p1ID].commit_s;
        newGame.commit_s2 = interestedPlayers[_p2ID].commit_s;
        newGame.commit_sd = _commitDealerSeed;
        newGame.timestamp_commit_sd = block.timestamp;
        gameDetails[gameIDGenerator] = newGame;
        emit notifyPlayerAboutGameID(_p1ID, _p2ID, newGame.gameID);
    }

    // Allows players to reveal their committed seed value for shuffling cards
    function revealSeedForShuffle(uint256 _gameID, uint256 _s) external onlyRegisteredPlayer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 p = getPlayerDetails[msg.sender].playerID;
        require(p == game.p1 || p == game.p2, "RR11");
        require(game.timestamp_commit_sd != 0, "RR12");
        if(p == game.p1)
        {
            require(game.timestamp_reveal_s1 == 0, "RR13");
            require((block.timestamp - game.timestamp_commit_sd) <= timelimit, "RR7");
            require(keccak256(abi.encodePacked(_s)) == game.commit_s1, "RR14");
            game.s1 = _s;
            game.timestamp_reveal_s1 = block.timestamp;
        }
        else
        {
            require(game.timestamp_reveal_s2 == 0, "RR13");
            require((block.timestamp - game.timestamp_commit_sd) <= timelimit, "RR7");
            require(keccak256(abi.encodePacked(_s)) == game.commit_s2, "RR14");
            game.s2 = _s;
            game.timestamp_reveal_s2 = block.timestamp;
        }
        gameDetails[_gameID] = game;
    }

    // Allows to compute the initial hash based on both players' seeds and blockchain related parameters
    function computeInitialHash(uint256 _gameID) external onlyDealer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        require(game.timestamp_reveal_s1 != 0, "RR15");
        require(game.timestamp_reveal_s2 != 0, "RR16");
        if(game.timestamp_reveal_s1 >= game.timestamp_reveal_s2)
        {
            require((block.timestamp - game.timestamp_reveal_s1) <= timelimit, "RR7");
        }
        else
        {
            require((block.timestamp - game.timestamp_reveal_s2) <= timelimit, "RR7");
        }
        game.initial_hash = keccak256( abi.encodePacked(game.s1, game.s2, block.timestamp, block.number) );
        game.timestamp_computing_initial_hash = block.timestamp;
        gameDetails[_gameID] = game;
    }

    // Allows the dealer to commit the encrypted hands of players and the Merkle root of the closed deck
    function commitPlayersEncHandAndClosedDeckMR(uint256 _gameID, bytes32 _commit_p1_enc_hand, bytes32 _commit_p2_enc_hand, bytes32 _MR_closed_deck) external onlyDealer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        require(game.timestamp_computing_initial_hash != 0, "RR17");
        require((block.timestamp - game.timestamp_computing_initial_hash) <= timelimit, "RR7");
        game.commit_p1_encrypted_hand = _commit_p1_enc_hand;
        game.commit_p2_encrypted_hand = _commit_p2_enc_hand;
        game.commit_MR_closed_deck = _MR_closed_deck;
        game.timestamp_commit_players_encrypted_hand_and_MR_closed_deck = block.timestamp;
        game.which_player_turn = game.p1;
        gameDetails[_gameID] = game;
    }
    
    // Allows players to provide consent before continuing the game after receiving their cards
    function provideConsent(uint256 _gameID, bool _consent) external onlyRegisteredPlayer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 p = getPlayerDetails[msg.sender].playerID;
        require(p == game.p1 || p == game.p2, "RR11");
        require(game.timestamp_commit_players_encrypted_hand_and_MR_closed_deck != 0, "RR18");
        if(p == game.p1)
        {
            require(game.timestamp_consent1 == 0,"RR19");
            require((block.timestamp - game.timestamp_commit_players_encrypted_hand_and_MR_closed_deck) <= timelimit, "RR7");
            game.consent1 = _consent;
            game.timestamp_consent1 = block.timestamp;
            if(_consent == false)
            {
                game.isGameAborted = true;
            }
        }
        else
        {
            game.consent2 = _consent;
            game.timestamp_consent2 = block.timestamp;
            if(_consent == false)
            {
                game.isGameAborted = true;
            }
        }
        gameDetails[_gameID] = game;
    }

    // Allows players to commit their seed for drawing a card from the closed deck (these seeds are different from the seeds used to shuffle the cards)
    function commitSeedForCardDrawn(uint256 _gameID, bytes32 _commit_s_prime) external onlyRegisteredPlayer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 p = getPlayerDetails[msg.sender].playerID;
        require(p == game.p1 || p == game.p2, "RR11");
        if(p == game.p1)
        {
            require(game.timestamp_consent1 != 0, "RR20");
            require(game.timestamp_commit_s1_prime == 0, "RR21");
            require((block.timestamp - game.timestamp_consent1) <= timelimit, "RR7");
            game.commit_s1_prime = _commit_s_prime;
            game.timestamp_commit_s1_prime = block.timestamp;
        }
        else
        {
            require(game.timestamp_consent2 != 0, "RR20");
            require(game.timestamp_commit_s2_prime == 0, "RR21");
            require((block.timestamp - game.timestamp_consent2) <= timelimit, "RR7");
            game.commit_s2_prime = _commit_s_prime;
            game.timestamp_commit_s2_prime = block.timestamp;
        }
        gameDetails[_gameID] = game;
    }

    // Allows a player to request a card from the closed deck
    function requestCardFromClosedDeck(uint256 _gameID) external onlyRegisteredPlayer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 p = getPlayerDetails[msg.sender].playerID;
        require(p == game.p1 || p == game.p2, "RR11");
        require(p == game.which_player_turn, "RR22");
        game.closedDeckCardCounter++;
        uint256 i = game.closedDeckCardCounter - 1;
        game.requestedBy[i] = p;
        game.timestamp_of_request[i] = block.timestamp;
        gameDetails[_gameID] = game;
        emit notifyDealerToSendClosedDeckCard(_gameID, p, dealer);
    }
    
    // Allows the dealer to send an encrypted card from the closed deck to the requesting player
    function sendCardFromClosedDeck(uint256 _gameID, bytes32 _enc_card, bytes32 _commit_card_by_dealer) external onlyDealer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 i = game.closedDeckCardCounter - 1;
        require(game.requestedBy[i] == game.which_player_turn, "RR23");
        require(game.timestamp_of_request[i] != 0, "RR24");
        require(game.timestamp_commit_card_by_dealer[i] == 0, "RR25");
        require( (block.timestamp - game.timestamp_of_request[i]) <= timelimit, "RR7");
        game.encryptedCard[i] = _enc_card;
        game.commit_card_by_dealer[i] = _commit_card_by_dealer;
        game.timestamp_commit_card_by_dealer[i] = block.timestamp;
        gameDetails[_gameID] = game;
    }
    
    // Allows the player to commit the card received from the closed deck
    function commitRecivedCard(uint256 _gameID, bytes32 _commit_card_by_player) external onlyRegisteredPlayer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 p = getPlayerDetails[msg.sender].playerID;
        require(p == game.p1 || p == game.p2, "RR11");
        require(p == game.which_player_turn, "RR22");
        uint256 i = game.closedDeckCardCounter - 1;
        require(p == game.requestedBy[i], "RR23");
        require(game.timestamp_commit_card_by_dealer[i] != 0,"RR26");
        require(game.timestamp_commit_card_by_player[i] == 0, "RR27");
        require((block.timestamp - game.timestamp_commit_card_by_dealer[i]) <= timelimit, "RR7");
        game.commit_card_by_player[i] = _commit_card_by_player;
        game.timestamp_commit_card_by_player[i] = block.timestamp;
        gameDetails[_gameID] = game;
    }

    // Allows a player to discard a card to the open deck
    function discardCardToOpenDeck(uint256 _gameID, uint256 _cardID) external onlyRegisteredPlayer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        uint256 p = getPlayerDetails[msg.sender].playerID;
        require(p == game.p1 || p == game.p2, "RR11");
        require(p == game.which_player_turn, "RR22");
        uint256 i = game.closedDeckCardCounter - 1;
        require(p == game.requestedBy[i], "RR23");
        require(game.timestamp_commit_card_by_player[i] != 0, "RR28");
        game.openDeckCardCounter++;
        uint256 j = game.openDeckCardCounter - 1;
        if(j != 0)
        {
            require(game.putBy[j-1] != p, "RR29");
        }
        game.putBy[j] = p;
        game.timestamp_put_card_on_open_deck[j] = block.timestamp;
        game.discardedCardID[j] = _cardID;
        if(p == game.p1)
        {
            game.which_player_turn = game.p2;
        }
        else 
        {
            game.which_player_turn = game.p1;
        }
        gameDetails[_gameID] = game;
    }

    // Allows the dealer to transfer the winning amount to the winner and deduct from the runner
    function transferWinningAmount(uint256 _gameID, uint256 _winnerID, uint256 _amount) external onlyDealer{
        Game memory game = gameDetails[_gameID];
        require(game.gameID > 0 && game.gameID <= gameIDGenerator, "RR9");
        require(game.isGameAborted == false, "RR10");
        require(_winnerID == game.p1 || _winnerID == game.p2, "RR30");
        uint256 _runnerID;
        if(_winnerID == game.p1)
        {
            _runnerID = game.p2;
        }
        else 
        {
            _runnerID = game.p1;
        }
        address _winnerAddr = getPlayerAddr[_winnerID];
        getPlayerDetails[_winnerAddr].currentStake += _amount;
        address _runnerAddr = getPlayerAddr[_runnerID];
        getPlayerDetails[_runnerAddr].currentStake -= _amount;
        game.winnerID = _winnerID;
        game.winningAmount = _amount;
        game.timestamp_reward = block.timestamp;
        game.isGameAborted = true;
        gameDetails[_gameID] = game;
    }

    // Allows players to unlock and withdraw a their staked money (partial/full)
    function unlockMoney(uint256 _amount) external onlyRegisteredPlayer{
        Player memory p = getPlayerDetails[msg.sender];
        require(p.currentStake >= _amount,"RR31");
        payable(msg.sender).transfer(_amount);
        p.currentStake -= _amount;
        getPlayerDetails[msg.sender] = p;
    }
}
