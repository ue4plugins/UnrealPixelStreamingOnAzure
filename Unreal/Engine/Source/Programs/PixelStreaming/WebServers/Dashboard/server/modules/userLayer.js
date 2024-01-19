function parseToken(token) {
  const buff = Buffer.from(token, "base64");
  return JSON.parse(buff.toString("utf-8"));
}

function getClaims(usrObject) {
  const claimsObj = {};
  if (!usrObject) {
    return claimsObj;
  }

  (usrObject.claims || []).forEach((claim) => {
    claimsObj[claim.typ] = claim.val;
  });

  return claimsObj;
}

module.exports = {
  parseToken,
  getClaims,
};
