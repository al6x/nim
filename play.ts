let text  = "therearemultiplereasonstoaboutforexeverysingleofthoseforextrendisbigenoughto"
let query = "foextrend"

function generateTrigrams(str: string): Map<string, number> {
  const trigramTable: Map<string, number> = new Map();

  for (let i = 0; i < str.length - 2; i++) {
    const trigram = str.slice(i, i + 3);
    const count = trigramTable.get(trigram) || 0;
    trigramTable.set(trigram, count + 1);
  }

  return trigramTable;
}

function calculateSimilarityScore(queryTrigramTable: Map<string, number>, textTrigramTable: Map<string, number>): number {
  let score = 0;

  for (const [trigram, queryCount] of queryTrigramTable.entries()) {
    const textCount = textTrigramTable.get(trigram) || 0;
    score += Math.min(queryCount, textCount);
  }

  return score;
}

function findBestMatchingSubstring(query: string, text: string): string {
  const queryTrigramTable = generateTrigrams(query.toLowerCase());

  let bestMatchingSubstring = "";
  let bestMatchingScore = 0;

  for (let i = 0; i < text.length - query.length + 1; i++) {
    const currentSubstring = text.slice(i, i + query.length);
    const currentTrigramTable = generateTrigrams(currentSubstring.toLowerCase());

    const currentMatchingScore = calculateSimilarityScore(queryTrigramTable, currentTrigramTable);
    if (currentMatchingScore > bestMatchingScore) {
      bestMatchingSubstring = currentSubstring;
      bestMatchingScore = currentMatchingScore;
    }
  }

  return bestMatchingSubstring;
}

const bestMatchingSubstring = findBestMatchingSubstring(query, text);
console.log(bestMatchingSubstring);
