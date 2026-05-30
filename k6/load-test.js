import http from "k6/http";
import { check, sleep } from "k6";

// BASE_URL points at the api service inside the compose network by default.
const BASE = __ENV.BASE_URL || "http://localhost:3000";
const ADMIN_EMAIL = __ENV.ADMIN_EMAIL || "admin@pokedex.local";
const ADMIN_PASSWORD = __ENV.ADMIN_PASSWORD || "changeme12345";

// A small pool so the first hit of each name is a cache miss (PokeAPI
// fetch) and the rest are cache hits, exercising the Redis-backed proxy
// and its hit/miss metrics.
const POKEMON = [
  "pikachu",
  "bulbasaur",
  "charmander",
  "squirtle",
  "eevee",
  "snorlax",
  "mewtwo",
  "gengar",
];

export const options = {
  stages: [
    { duration: "30s", target: 10 },
    { duration: "1m", target: 10 },
    { duration: "15s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<1500"],
  },
};

// setup runs once before the load stages: sign in as the seeded admin and
// hand the token to every VU so the JWT-protected pokemon routes (and thus
// the Redis cache metrics) are actually exercised.
export function setup() {
  const res = http.post(
    `${BASE}/api/auth/signin`,
    JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
    { headers: { "Content-Type": "application/json" } },
  );
  check(res, { "signin 200": (r) => r.status === 200 });
  return { token: res.json("token") };
}

export default function (data) {
  const authHeaders = {
    headers: { Authorization: `Bearer ${data.token}` },
  };

  const welcome = http.get(`${BASE}/api`);
  check(welcome, { "welcome 200": (r) => r.status === 200 });

  const name = POKEMON[Math.floor(Math.random() * POKEMON.length)];
  const pokemon = http.get(`${BASE}/api/pokemon/${name}`, authHeaders);
  check(pokemon, { "pokemon 200": (r) => r.status === 200 });

  sleep(1);
}
