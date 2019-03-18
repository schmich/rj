package main

import (
  "fmt"
  "io/ioutil"
  "path"
  "time"
  "os"
  "os/exec"
  "os/signal"
  "errors"
  "github.com/mitchellh/go-homedir"
)

var version string
var commit string
var payloadDir string

func delay(fn func(), delay time.Duration) chan<- bool {
  cancel := make(chan bool, 1)

  go func () {
    wait := make(chan bool)
    go func () {
      time.Sleep(delay)
      wait <- true
      close(wait)
    }()

    select {
    case <-wait:
      fn()
    case <-cancel:
    }
  }()

  return cancel
}

func deployRuntime() (string, error) {
  if len(payloadDir) == 0 {
    return "", errors.New("Invalid payload directory.")
  }

  home, err := homedir.Dir()
  if err != nil {
    return "", err
  }

  rjHome := path.Join(home, ".rj")
  err = os.Mkdir(rjHome, 0700)
  if err != nil && !os.IsExist(err) {
    return "", err
  }

  files, err := ioutil.ReadDir(rjHome)
  if err != nil {
    return "", err
  }

  for _, file := range files {
    if file.IsDir() && file.Name() != payloadDir {
      remove := path.Join(rjHome, file.Name())
      os.RemoveAll(remove)
    }
  }

  dir := path.Join(rjHome, payloadDir)
  err = os.Mkdir(dir, 0700)
  if os.IsExist(err) {
    return dir, nil
  }

  cancel := delay(func () {
    log.Println("Preparing for first use.")
  }, 500 * time.Millisecond)

  // TODO: Show "prepared" message.

  err = RestoreAssets(dir, "runtime")
  cancel <- true

  if err != nil {
    return "", err
  }

  return dir, nil
}

func main() {
  // We exclude the first argument since it's just the current process path.
  args := os.Args[1:]
  if len(args) == 1 && (args[0] == "-v" || args[0] == "--version") {
    fmt.Fprintln(os.Stderr, "rj", version, commit)
    return
  }

  dir, err := deployRuntime()
  if err != nil {
    log.Fatal(err)
    return
  }

  ruby := setupRuntime(dir)
  script := path.Join(dir, "runtime", "lib", "app", "main.rb")
  args = append([]string{script}, args...)

  // Disable all default signal behavior (e.g. SIGINT)
  // in case child process has specific signal handling.
  signals := make(chan os.Signal, 1)
  signal.Notify(signals)

  cmd := exec.Command(ruby, args...)
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr
  cmd.Stdin = os.Stdin
  cmd.Run()
}
