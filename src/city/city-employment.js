const JOBS_PER_BUILDING = Object.freeze({ shop: 9, industrial: 18, administrative: 12, service: 6 });
const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, value));

/** Aggregate workforce matching; pedestrian sprites remain a bounded visual sample. */
export function computeCityEmployment(city) {
  if (!city || !Array.isArray(city.buildings) || !Number.isFinite(city.population) || city.population < 0) {
    throw new TypeError("A valid city population and building list are required");
  }
  const counts = Object.fromEntries(Object.keys(JOBS_PER_BUILDING).map(type => [type, city.buildings.filter(b => b.type === type).length]));
  const capacity = Object.fromEntries(Object.entries(JOBS_PER_BUILDING).map(([type, slots]) => [type, counts[type] * slots]));
  const jobs = Object.values(capacity).reduce((sum, value) => sum + value, 0);
  const laborForce = Math.floor(city.population * 0.6);
  let remaining = laborForce;
  const bySector = {};
  for (const type of ["industrial", "shop", "administrative", "service"]) {
    const employed = Math.min(capacity[type], remaining);
    remaining -= employed;
    bySector[type] = Object.freeze({ workplaces: counts[type], capacity: capacity[type], employed, vacancies: capacity[type] - employed });
  }
  const employed = laborForce - remaining;
  const unemployed = remaining;
  const vacancies = jobs - employed;
  const unemploymentRate = laborForce ? Math.round(unemployed / laborForce * 100) : 0;
  const unmetLaborDemand = Math.max(0, laborForce - jobs);
  return Object.freeze({
    jobs, laborForce, employed, unemployed, vacancies, unemploymentRate,
    participationRate: city.population ? Math.round(laborForce / city.population * 100) : 0,
    laborShortage: Math.max(0, jobs - laborForce), unmetLaborDemand,
    demandIndex: laborForce ? clamp(Math.round(unmetLaborDemand / laborForce * 100), 0, 100) : 0,
    bySector: Object.freeze(bySector)
  });
}
export { JOBS_PER_BUILDING };
