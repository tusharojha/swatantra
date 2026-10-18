/**
 * SIWE into Arkiv Hub and try the faucet. Captcha may still be required.
 * Usage: node --env-file=../.env src/fund.mjs
 */
import { privateKeyToAccount } from "viem/accounts";
import { createSiweMessage } from "viem/siwe";

const HUB = "https://hub.arkiv.network";
const keys = [
  process.env.SEED_PRIVATE_KEY,
  process.env.JOURNALIST_A_KEY,
  process.env.JOURNALIST_B_KEY,
  process.env.JOURNALIST_C_KEY,
].filter(Boolean);

async function fund(pk) {
  const account = privateKeyToAccount(pk);
  const address = account.address;
  const chainId = 7738577;
  const jar = [];
  const saveCookies = (res) => {
    const c = res.headers.getSetCookie?.() ?? [];
    for (const line of c) jar.push(line.split(";")[0]);
  };
  const cookie = () => jar.join("; ");

  const headers = {
    "content-type": "application/json",
    origin: HUB,
    referer: `${HUB}/faucet`,
  };
  const nonceRes = await fetch(`${HUB}/api/auth/siwe/nonce`, {
    method: "POST",
    headers,
    body: JSON.stringify({ walletAddress: address, chainId }),
  });
  saveCookies(nonceRes);
  const { nonce } = await nonceRes.json();
  const message = createSiweMessage({
    domain: "hub.arkiv.network",
    address,
    statement: "Sign in to Arkiv Hub.",
    uri: HUB,
    version: "1",
    chainId,
    nonce,
  });
  const signature = await account.signMessage({ message });
  const verifyRes = await fetch(`${HUB}/api/auth/siwe/verify`, {
    method: "POST",
    headers: { ...headers, cookie: cookie() },
    body: JSON.stringify({
      message,
      signature,
      walletAddress: address,
      chainId,
    }),
  });
  saveCookies(verifyRes);
  const verifyJson = await verifyRes.json();
  console.log(address, "siwe", verifyRes.status, JSON.stringify(verifyJson).slice(0, 300));

  const getRes = await fetch(`${HUB}/api/faucet?recipient=${address}`, {
    headers: { origin: HUB, referer: `${HUB}/faucet`, cookie: cookie() },
  });
  const getText = await getRes.text();
  console.log(address, "GET faucet", getRes.status, getText.slice(0, 400));

  const postRes = await fetch(`${HUB}/api/faucet`, {
    method: "POST",
    headers: { ...headers, cookie: cookie() },
    body: JSON.stringify({ recipient: address, captchaToken: "e2e" }),
  });
  const postText = await postRes.text();
  console.log(address, "POST faucet", postRes.status, postText.slice(0, 400));
}

for (const pk of keys) {
  try {
    await fund(pk);
  } catch (e) {
    console.error(e);
  }
}
