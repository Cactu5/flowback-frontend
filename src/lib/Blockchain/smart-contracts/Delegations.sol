// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import './RightToVote.sol';

contract Delegations is RightToVote {
    //Mapping over who is delegate in which group
    mapping(uint => GroupDelegate[]) public groupDelegates;
    //Mapping that keeps track of the number of delegates corresponding to groupId
    mapping(uint => uint) internal groupDelegateCount;
    // Mapping over which groups users have delegated in by address
    mapping(address => uint[]) internal groupDelegationsByUser;

    struct GroupDelegate {
        address delegate;
        uint groupId;
        uint delegatedVotes;
        address[] delegationsFrom;
        uint groupDelegateId;
    }

    event NewDelegate(address indexed delegate, uint indexed groupId, uint delegatedVotes, address[] delegationsFrom, uint groupDelegateId);

    function becomeDelegate(uint _groupId) public {
        require(!addressIsDelegate(_groupId, msg.sender), "You are already a delegate i specific group");
        groupDelegateCount[_groupId]++;

        GroupDelegate memory newGroupDelegate = GroupDelegate({
            delegate: msg.sender,
            groupId: _groupId,
            delegatedVotes: 0,
            delegationsFrom: new address[](0),
            groupDelegateId: groupDelegateCount[_groupId]
        });

        groupDelegates[_groupId].push(newGroupDelegate);

        emit NewDelegate(newGroupDelegate.delegate, newGroupDelegate.groupId, newGroupDelegate.delegatedVotes, newGroupDelegate.delegationsFrom, newGroupDelegate.groupDelegateId);
    }

    event NewDelegation(address indexed from, address indexed to, uint indexed groupId, uint delegatedVotes, address[] delegationsFrom);

    function delegate(uint _groupId, address _delegateTo) public {
        require(addressIsDelegate(_groupId, _delegateTo), "The address is not a delegate in the specified group");
        require(delegaterIsInGroup(_groupId), "You can only delegate in groups you are a member of.");
        require(!hasDelegatedInGroup(_groupId), "You have an active delegation in this group.");
        require(_delegateTo != msg.sender, "You can not delegate to yourself");
        // add active delegation to groupDelegationsByUser
        groupDelegationsByUser[msg.sender].push(_groupId);
        // increase the delegates delegatedVotes
        uint delegatedVotes;
        address[] memory delegationsFrom;
        uint arrayLength = groupDelegates[_groupId].length;
        for (uint i; i < arrayLength;) {
            if (groupDelegates[_groupId][i].delegate == _delegateTo) {
                groupDelegates[_groupId][i].delegatedVotes++;
                groupDelegates[_groupId][i].delegationsFrom.push(msg.sender);
                delegatedVotes = groupDelegates[_groupId][i].delegatedVotes;
                delegationsFrom = groupDelegates[_groupId][i].delegationsFrom;
            }

            unchecked {
                ++i;
            }
        }

        emit NewDelegation(msg.sender, _delegateTo, _groupId, delegatedVotes, delegationsFrom);
    }

    event DelegationRemoved(address indexed from, address indexed by, uint indexed groupId, uint delegatedVotes);

    function removeDelegation(address _delegate, uint _groupId) public {
        // check that the user has delegated to the specified delegate in the specified group
        require(hasDelegatedToDelegateInGroup(_groupId, _delegate), "You have not delegated to the specified delegate in this group");
        // decrease the number of delegated votes from the delegate
        // remove the user from the delegates delegationsFrom array
        uint delegatedVotes;
        uint arrayLength = groupDelegates[_groupId].length;
        for (uint i; i < arrayLength;) {
            if (groupDelegates[_groupId][i].delegate == _delegate) {
                groupDelegates[_groupId][i].delegatedVotes--;
                delegatedVotes = groupDelegates[_groupId][i].delegatedVotes;
                for (uint k; k < groupDelegates[_groupId][i].delegationsFrom.length;) {
                    if (groupDelegates[_groupId][i].delegationsFrom[k] == msg.sender) {
                        delete groupDelegates[_groupId][i].delegationsFrom[k];
                    }

                    unchecked {
                        ++k;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
        // remove the group from the user's groupDelegationsByUser array
        arrayLength = groupDelegationsByUser[msg.sender].length;
        for (uint i; i < arrayLength;) {
            if (groupDelegationsByUser[msg.sender][i] == _groupId) {
                delete groupDelegationsByUser[msg.sender][i];
            }

            unchecked {
                ++i;
            }
        }
        emit DelegationRemoved(_delegate, msg.sender, _groupId, delegatedVotes);
    }

    event DelegateResignation(address indexed delegate, uint indexed groupId);

    function resignAsDelegate(uint _groupId) public {
        address[] memory affectedUsers;
         require(addressIsDelegate(_groupId, msg.sender), "You are not a delegate in requested group");
        // remove groupDelegationsByUsers for affected users
        uint arrayLength = groupDelegates[_groupId].length;
        for (uint i; i < arrayLength;) {
            if (groupDelegates[_groupId][i].delegate == msg.sender) {
                affectedUsers = groupDelegates[_groupId][i].delegationsFrom;
                delete groupDelegates[_groupId][i];
            }

            unchecked {
                ++i;
            }
        }

        for (uint i; i < affectedUsers.length; i++) {
            arrayLength = groupDelegationsByUser[affectedUsers[i]].length;
            for (uint k; k < arrayLength;) {
                if (groupDelegationsByUser[affectedUsers[i]][k] == _groupId) {
                    delete groupDelegationsByUser[affectedUsers[i]][k];
                }

                unchecked {
                    ++k;
                }
            }
        }
        emit DelegateResignation(msg.sender, _groupId);
    }

    function addressIsDelegate(uint _groupId, address _potentialDelegate) view private returns(bool isDelegate) {
        uint arrayLength = groupDelegates[_groupId].length;
        for (uint i; i < arrayLength;) {
            if (groupDelegates[_groupId][i].delegate == _potentialDelegate) {
                return true;
            }

            unchecked {
                ++i;
            }
        }
        return false;
    }

    function delegaterIsInGroup(uint _groupId) view private returns(bool isInGroup) {
        uint arrayLength = voters[msg.sender].groups.length;
        for (uint i; i < arrayLength;) {
            if (voters[msg.sender].groups[i] == _groupId) {
                return true;
            }

            unchecked {
                ++i;
            }
        }
        return false;
    }

    // function hasDelegatedInGroup(uint _groupId) public view returns (bool) {
    //     uint[] memory userDelegatedGroups = groupDelegationsByUser[msg.sender];
    //     for (uint i; i < userDelegatedGroups.length;) {
    //         if (userDelegatedGroups[i] == _groupId) {
    //             return true;
    //         }

    //         unchecked {
    //             ++i;
    //         }
    //     }
    //     return false;
    // }

    function hasDelegatedInGroup(uint _groupId) public view returns (bool) {
        uint[] memory userDelegatedGroups = groupDelegationsByUser[msg.sender];
        for (uint i; i < userDelegatedGroups.length;) {
            if (userDelegatedGroups[i] == _groupId) {
                return true;
            }

            unchecked {
                ++i;
            }
        }
        return false;
    }

    function hasDelegatedToDelegateInGroup(uint _groupId, address _delegate) public view returns (bool) {
        uint arrayLength = groupDelegates[_groupId].length;
        for (uint i; i < arrayLength;) {
            if (groupDelegates[_groupId][i].delegate == _delegate) {
                arrayLength = groupDelegates[_groupId][i].delegationsFrom.length;
                for (uint k; k < arrayLength;) {
                    if (groupDelegates[_groupId][i].delegationsFrom[k] == msg.sender) {
                        return true;
                    }

                    unchecked {
                        ++k;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
        return false;
    }

}