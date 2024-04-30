// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Whistler {

struct Report { 
        // We'll omit storing the content directly for now
        string title; // Report title
        bytes32 contentHash; // IPFS hash of the report content
        uint256 timestamp; 
        uint256 upvoteCount;
        mapping(uint256 => Comment) comments; 
        
    }

    struct ReportCommitment {
        bytes32 commitmentHash;
        uint256 timestamp; 
    }

    struct Comment {
       string content; // For the comment text
       uint256 timestamp; 
    }

    /// @notice The root hash of the Merkle tree storing report commitments.
    bytes32 public merkleRoot; 

    /// @notice Maps report IDs to their corresponding commitment and timestamp.
    mapping(uint256 => ReportCommitment) public reports; 


    // Mapping to track if a temporary ID has upvoted a report
    mapping(bytes32 => mapping (uint256 => bool)) public hasUpvoted;


    /// @notice The next available report ID.
    uint256 public nextReportId;

    /// @notice An array to temporarily store report commitment hashes for Merkle tree operations.
    bytes32[] commitments; // Array to store report commitment hashes

     /// @notice Event emitted when a new report is submitted.
    event ReportSubmitted(uint256 indexed reportId);

    /// @notice Event emitted when a report is upvoted.
    event ReportUpvoted(uint256 indexed reportId);

    /// @notice Event emitted when a new comment is submitted.
    event CommentSubmitted(uint256 indexed reportId, uint256 indexed commentId);


    /// @notice Allows a user to submit a new report.
    /// @dev The report content is not stored directly on-chain but is instead represented by a commitment hash.
    /// @param commitmentHash The hash representing the report content, secret, and potential nullifier.
    /// @param proof The Merkle proof demonstrating the commitmentHash exists in the tree.
    function submitReport(bytes32 commitmentHash, bytes32 contentHash, string memory title, bytes32[] calldata proof) public { 
        require(MerkleProof.verify(proof, merkleRoot, commitmentHash), "Invalid report commitment");

        commitments.push(commitmentHash); 
        merkleRoot = MerkleTree.getRoot(commitments); 

        reports[nextReportId] = ReportCommitment(commitmentHash, block.timestamp,0,contentHash, title);
        nextReportId++;

        reports[nextReportId] = Report(
        block.timestamp,
        0, 
        contentHash,
        title
    );


        emit ReportSubmitted(nextReportId - 1);
    }

        /// @notice Upvotes a report (with duplicate prevention using temporary identifiers).
    /// @param reportId The ID of the report to upvote.
    function upvoteReport(uint256 reportId) public {
        require(reports[reportId].timestamp > 0, "Report not found");

        // Generate a somewhat unique temporary ID for the user
        bytes32 tempId = keccak256(abi.encodePacked(msg.sender, block.timestamp, reports[reportId].upvoteCount));

        require(!hasUpvoted[tempId][reportId], "You have already upvoted this report"); 

        reports[reportId].upvoteCount++;
        hasUpvoted[tempId][reportId] = true; 
        emit ReportUpvoted(reportId);
    }

    /// @notice Allows a user to submit a comment on a report.
    /// @param reportId The ID of the report to comment on.
    /// @param content The content of the comment.
    function submitComment(uint256 reportId, string memory content) public {
        require(reports[reportId].timestamp > 0, "Report not found");

        // Generate a comment ID
        uint256 commentId = uint256(keccak256(abi.encodePacked(reportId, reports[reportId].comments.length)));

        reports[reportId].comments[commentId].content = content;
        reports[reportId].comments[commentId].timestamp = block.timestamp;

        emit CommentSubmitted(reportId, commentId);
    }

    function getReports() public view returns (uint256[] memory) {
        uint256[] memory allReportIds = new uint256[](nextReportId);
            for (uint256 i = 0; i < nextReportId; i++) {
                allReportIds[i] = i;
            }
        return allReportIds;
    }

    // Additional Getters 
    function getReportUpvotes(uint256 reportId) public view returns (uint256) {
        return reports[reportId].upvoteCount;
    }

    function getComment(uint256 reportId, uint256 commentId) public view returns (string memory, uint256) {
        Comment storage comment =  reports[reportId].comments[commentId];
        return (comment.content, comment.timestamp);
    }
}


