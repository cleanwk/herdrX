// HerdrX transport adapter. The upstream Tailcat library implements WireGuard/DERP.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/tailscale/tailcat"
	"tailscale.com/types/key"
)

type credentials struct {
	Token string `json:"token"`
	Key   string `json:"key"`
}

func run() error {
	if len(os.Args) == 2 && os.Args[1] == "keygen" {
		k := key.NewNode()
		private, err := k.MarshalText()
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(map[string]string{"private": string(private), "public": k.Public().String()})
	}
	if len(os.Args) != 2 {
		return errors.New("expected private socket directory")
	}
	var input credentials
	if err := json.NewDecoder(io.LimitReader(os.Stdin, 16384)).Decode(&input); err != nil {
		return err
	}
	var identity key.NodePrivate
	if err := identity.UnmarshalText([]byte(input.Key)); err != nil || identity.IsZero() {
		return errors.New("invalid client identity")
	}
	if input.Token == "" {
		return errors.New("missing connection token")
	}
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()
	client := tailcat.NewClient(tailcat.ConnBlob(input.Token))
	client.Key = identity
	client.Logf = func(string, ...any) {}
	defer client.Close()
	var listeners []net.Listener
	defer func() {
		for _, l := range listeners {
			l.Close()
		}
	}()
	for _, spec := range []struct {
		name string
		port uint16
	}{{"herdr.sock", 6464}, {"herdr-client.sock", 6465}} {
		path := filepath.Join(os.Args[1], spec.name)
		ln, err := net.Listen("unix", path)
		if err != nil {
			return err
		}
		listeners = append(listeners, ln)
		if err := os.Chmod(path, 0600); err != nil {
			return err
		}
		go func(ln net.Listener, port uint16) {
			for {
				local, err := ln.Accept()
				if err != nil {
					return
				}
				go func() {
					defer local.Close()
					deadline, done := context.WithTimeout(ctx, 20*time.Second)
					remote, err := client.DialTCPPort(deadline, port)
					done()
					if err != nil {
						fmt.Fprintln(os.Stderr, "Tailcat connection failed; verify token and host allowlist")
						return
					}
					defer remote.Close()
					var once sync.Once
					stop := func() { once.Do(func() { local.Close(); remote.Close() }) }
					go func() { io.Copy(remote, local); stop() }()
					io.Copy(local, remote)
					stop()
				}()
			}
		}(ln, spec.port)
	}
	<-ctx.Done()
	return nil
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
