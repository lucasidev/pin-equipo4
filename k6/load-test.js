import http from "k6/http";
import { check, sleep } from "k6";

// BASE_URL points at the api service inside the compose network by default.
const BASE = __ENV.BASE_URL || "http://localhost:3000";

// A small pool of names so the first hit of each is a cache miss (PokeAPI
// fetch) and the rest are cache hits, exercising the Redis-backed proxy and
// its hit/miss metrics.
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

export default function () {
  const welcome = http.get(`${BASE}/api`);
  check(welcome, { "welcome 200": (r) => r.status === 200 });

  const name = POKEMON[Math.floor(Math.random() * POKEMON.length)];
  const pokemon = http.get(`${BASE}/api/pokemon/${name}`);
  check(pokemon, { "pokemon 200": (r) => r.status === 200 });

  sleep(1);
}
