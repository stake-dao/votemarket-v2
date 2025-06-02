const fs = require("node:fs");
const path = require("node:path");

async function main() {
	// Get command line arguments
	const args = process.argv.slice(2);

	// Validate arguments
	if (args.length !== 4) {
		console.error(
			"Usage: node update-votemarket.js <protocol> <platform> <chainIds> <seed>",
		);
		console.error(
			'Example: node update-votemarket.js curve 0x1234...5678 "[10,42161,8453]" 1234567890',
		);
		process.exit(1);
	}

	const [protocol, platform, chainIdsStr, seed] = args;

	// Parse chainIds from string array to actual array of numbers
	let chainIds;
	try {
		chainIds = JSON.parse(chainIdsStr);
		if (!Array.isArray(chainIds)) throw new Error("chainIds must be an array");
	} catch (error) {
		console.error("Error: chainIds must be a valid JSON array of numbers");
		console.error('Example: "[10,42161,8453]"');
		process.exit(1);
	}

	// Validate platform address format
	if (!/^0x[a-fA-F0-9]{40}$/.test(platform)) {
		console.error("Error: platform must be a valid Ethereum address");
		process.exit(1);
	}

	// Read the current database
	const dbPath = path.join(__dirname, "votemarkets.json");
	let database;
	try {
		database = JSON.parse(fs.readFileSync(dbPath, "utf8"));
	} catch (error) {
		console.error("Error reading database:", error);
		process.exit(1);
	}

	// Validate the seed has the length of a bytes8 (16 (bytes8) + 2 (0x))
	if (seed.length !== 18 || !seed.startsWith("0x")) {
		console.error("Error: seed must be a valid bytes8");
		process.exit(1);
	}

	// Create new entries
	const newEntries = chainIds.map((chainId) => ({
		protocol: protocol.toLowerCase(),
		chainId,
		platform,
		seed,
	}));

	// Add new entries to the database
	database.data = [...newEntries, ...database.data];

	// Update the count
	database.count = database.data.length;

	// Write the updated database back to file
	try {
		fs.writeFileSync(dbPath, JSON.stringify(database, null, "\t"));
	} catch (error) {
		console.error("Error writing database:", error);
		process.exit(1);
	}
}

// Run the main function and handle any uncaught errors
main()
	.then((success) => {
		console.log("0xAA");
		if (success) {
			process.exit(0);
		}
	})
	.catch((error) => {
		console.error("Unexpected error:", error);
		process.exit(1);
	});
