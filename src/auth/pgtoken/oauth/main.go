// pgtoken-oauth.so: mints an access token for a PostgreSQL server that takes OAuth logins.
//
// pgtoken.so loads it at the moment a server asks for a token, and calls pgtoken_mint. What it does is the JWT
// profile of OAuth 2.0 (RFC 7523): an assert signed by the ssh agent's key says who logs in, and is exchanged at
// the token endpoint for an access token. The client that asks is named and has no secret and no key: it decides
// nothing. Whether a token is given rests on the trust the authorization server holds for the signing key, and on
// what its token hook writes into the token. Every part is somebody's library:
//
//	the signature  go.ptx.dk/ssh-jwt, the package of the ssh-jwt tool: the key stays in the agent
//	the issuer     github.com/coreos/go-oidc: its discovery document
//	the exchange   golang.org/x/oauth2: the request to the token endpoint and what it answers
//
//	go build -buildmode=c-shared -trimpath -ldflags='-s -w' -o pgtoken-oauth.so .
package main

/*
#include <stdlib.h>

typedef struct {
	const char *discovery, *server, *client_id, *scope, *audience, *subject;
	int allow_http;
} pgtoken_request;
*/
import "C"

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/golang-jwt/jwt/v5"
	sshjwt "go.ptx.dk/ssh-jwt"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/clientcredentials"
)

const (
	assertGrant = "urn:ietf:params:oauth:grant-type:jwt-bearer"
	discovery   = "/.well-known/openid-configuration"
)

type request struct {
	discovery, server, clientID, scope, audience, subject string
	allowHTTP                                             bool
}

var signer sync.Once

// secure refuses an address without TLS, unless the caller is libpq's own test mode.
func secure(address string, allowHTTP bool) error {
	if strings.HasPrefix(address, "https://") || (allowHTTP && strings.HasPrefix(address, "http://")) {
		return nil
	}
	return fmt.Errorf("not an https address: %s", address)
}

// statement is what the assert says: who, to that endpoint alone, for two minutes, once.
func statement(who, endpoint string) (jwt.MapClaims, error) {
	id := make([]byte, 16)
	if _, err := rand.Read(id); err != nil {
		return nil, err
	}
	now := time.Now()
	return jwt.MapClaims{
		"iss": who,
		"sub": who,
		"aud": endpoint,
		"iat": now.Unix(),
		"exp": now.Add(2 * time.Minute).Unix(),
		"jti": hex.EncodeToString(id),
	}, nil
}

// assert is the user's statement, which the token endpoint takes in the place of a password: signed by the key
// in the ssh agent.
func assert(subject, endpoint string) (string, error) {
	claims, err := statement(subject, endpoint)
	if err != nil {
		return "", err
	}
	signer.Do(sshjwt.RegisterSigner)
	agent, err := sshjwt.DefaultAgent()
	if err != nil {
		return "", fmt.Errorf("the ssh agent: %w", err)
	}
	key, err := agent.FirstKey()
	if err != nil {
		return "", fmt.Errorf("the ssh agent: %w", err)
	}
	signed, err := jwt.NewWithClaims(sshjwt.SSHSigningMethod, claims).SignedString(key)
	if err != nil {
		return "", fmt.Errorf("the ssh agent did not sign: %w", err)
	}
	return signed, nil
}

// at is an address of the issuer as the server has it: the same path, where the server is reached.
func at(server, issuer, address string) (string, error) {
	there, err := url.Parse(address)
	if err != nil {
		return "", err
	}
	here, err := url.Parse(server)
	if err != nil {
		return "", err
	}
	root, err := url.Parse(issuer)
	if err != nil {
		return "", err
	}
	here.Path = strings.TrimRight(here.Path, "/") + strings.TrimPrefix(there.Path, strings.TrimRight(root.Path, "/"))
	here.RawQuery = there.RawQuery
	return here.String(), nil
}

// mint asks the authorization server for a token of the issuer. The issuer is the one the connection trusts and
// the PostgreSQL server names; the server is where it is reached, the issuer itself when none is given. Reached
// elsewhere, it must still say it is that issuer, and the assert is addressed to the issuer's own endpoint.
func mint(r request) (string, error) {
	issuer, ok := strings.CutSuffix(r.discovery, discovery)
	if !ok {
		return "", fmt.Errorf("the server's discovery address is not an OpenID one: %s", r.discovery)
	}
	server := strings.TrimRight(r.server, "/")
	if server == "" {
		server = issuer
	}
	if err := secure(server, r.allowHTTP); err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	ctx = oidc.ClientContext(ctx, &http.Client{Timeout: 20 * time.Second}) // the exchange below uses it too
	if server != issuer {
		// go-oidc checks the document's issuer against the address it was fetched from, or, with this, not at
		// all. Fetched elsewhere it is checked below, against the issuer the connection trusts.
		ctx = oidc.InsecureIssuerURLContext(ctx, issuer)
	}
	provider, err := oidc.NewProvider(ctx, server)
	if err != nil {
		return "", fmt.Errorf("the issuer %s at %s: %w", issuer, server, err)
	}
	var document struct {
		Issuer string `json:"issuer"`
	}
	if err := provider.Claims(&document); err != nil {
		return "", err
	}
	if document.Issuer != issuer {
		return "", fmt.Errorf("%s is the issuer %s, the connection trusts %s", server, document.Issuer, issuer)
	}
	official := provider.Endpoint().TokenURL
	endpoint := official
	if server != issuer {
		if endpoint, err = at(server, issuer, official); err != nil {
			return "", err
		}
	}
	if err := secure(endpoint, r.allowHTTP); err != nil {
		return "", err
	}
	signed, err := assert(r.subject, official)
	if err != nil {
		return "", err
	}
	exchange := clientcredentials.Config{
		ClientID:       r.clientID,
		TokenURL:       endpoint,
		Scopes:         strings.Fields(r.scope),
		AuthStyle:      oauth2.AuthStyleInParams,
		EndpointParams: url.Values{"grant_type": {assertGrant}, "assertion": {signed}},
	}
	if r.audience != "" {
		exchange.EndpointParams.Set("audience", r.audience)
	}
	token, err := exchange.Token(ctx)
	if err != nil {
		var refused *oauth2.RetrieveError
		if errors.As(err, &refused) && refused.ErrorCode != "" {
			return "", fmt.Errorf("%s refused the exchange for the client %s: %s: %s",
				endpoint, r.clientID, refused.ErrorCode, refused.ErrorDescription)
		}
		return "", fmt.Errorf("%s: %w", endpoint, err)
	}
	return token.AccessToken, nil
}

// pgtoken_mint returns the access token, or nil with *problem set. The caller frees both.
//
//export pgtoken_mint
func pgtoken_mint(r *C.pgtoken_request, problem **C.char) (token *C.char) {
	defer func() {
		if failure := recover(); failure != nil {
			*problem, token = C.CString(fmt.Sprint(failure)), nil
		}
	}()
	minted, err := mint(request{
		discovery: C.GoString(r.discovery), server: C.GoString(r.server),
		clientID: C.GoString(r.client_id),
		scope:    C.GoString(r.scope), audience: C.GoString(r.audience), subject: C.GoString(r.subject),
		allowHTTP: r.allow_http != 0,
	})
	if err != nil {
		*problem = C.CString(err.Error())
		return nil
	}
	return C.CString(minted)
}

func main() {}
