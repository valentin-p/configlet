import std/[json, os, sets]
import pkg/[parsetoml]
import ".."/[cli]

type
  ConfigJsonExercise = object
    slug: string

  ConfigJson = object
    practice: seq[ConfigJsonExercise]

  TrackRepo = object
    dir: string

  TrackRepoExercise = object
    dir: string

  TrackExerciseTests* = object
    included*: HashSet[string]
    excluded*: HashSet[string]

  TrackExercise* = object
    slug*: string
    tests*: TrackExerciseTests
    repoExercise: TrackRepoExercise

proc configJsonFile(repo: TrackRepo): string =
  repo.dir / "config.json"

proc exercisesDir(repo: TrackRepo): string =
  repo.dir / "exercises"

proc practiceExerciseDir(repo: TrackRepo, exercise: ConfigJsonExercise): string =
  repo.exercisesDir / "practice" / exercise.slug

proc slug(exercise: TrackRepoExercise): string =
  extractFilename(exercise.dir)

proc testsFile(exercise: TrackRepoExercise): string =
  exercise.dir / ".meta" / "tests.toml"

proc testsFile*(exercise: TrackExercise): string =
  exercise.repoExercise.testsFile

proc parseConfigJson(filePath: string): ConfigJson =
  let json = json.parseFile(filePath)["exercises"]
  to(json, ConfigJson)

proc newTrackRepoExercise(repo: TrackRepo,
    exercise: ConfigJsonExercise): TrackRepoExercise =
  result.dir = repo.practiceExerciseDir(exercise)

proc exercises(repo: TrackRepo): seq[TrackRepoExercise] =
  let config = parseConfigJson(repo.configJsonFile)

  for exercise in config.practice:
    result.add(newTrackRepoExercise(repo, exercise))

proc newTrackExerciseTests(exercise: TrackRepoExercise): TrackExerciseTests =
  if not fileExists(exercise.testsFile):
    return

  let tests = parsetoml.parseFile(exercise.testsFile)
  if not tests.hasKey("canonical-tests"):
    return

  for uuid, enabled in tests["canonical-tests"].getTable():
    if enabled.getBool():
      result.included.incl(uuid)
    else:
      result.excluded.incl(uuid)

proc newTrackExercise(exercise: TrackRepoExercise): TrackExercise =
  result.slug = exercise.slug
  result.tests = newTrackExerciseTests(exercise)

proc findTrackExercises(repo: TrackRepo, conf: Conf): seq[TrackExercise] =
  for repoExercise in repo.exercises:
    if conf.action.exercise.len == 0 or conf.action.exercise == repoExercise.slug:
      result.add(newTrackExercise(repoExercise))

proc findTrackExercises*(conf: Conf): seq[TrackExercise] =
  let trackRepo = TrackRepo(dir: conf.trackDir)
  trackRepo.findTrackExercises(conf)
