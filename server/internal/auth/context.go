package auth

import "context"

type contextKey int

const (
	ctxUserID contextKey = iota
	ctxVaultID
	ctxDeviceID
)

// Identity is the authenticated caller attached to the request context by
// the RequireAuth middleware.
type Identity struct {
	UserID   string
	VaultID  string
	DeviceID string
}

func withIdentity(ctx context.Context, id Identity) context.Context {
	ctx = context.WithValue(ctx, ctxUserID, id.UserID)
	ctx = context.WithValue(ctx, ctxVaultID, id.VaultID)
	ctx = context.WithValue(ctx, ctxDeviceID, id.DeviceID)
	return ctx
}

// CurrentIdentity extracts the authenticated caller from ctx. ok is false
// if the request was not authenticated (RequireAuth was not applied or
// failed before this point).
func CurrentIdentity(ctx context.Context) (Identity, bool) {
	userID, ok1 := ctx.Value(ctxUserID).(string)
	vaultID, ok2 := ctx.Value(ctxVaultID).(string)
	deviceID, ok3 := ctx.Value(ctxDeviceID).(string)
	if !ok1 || !ok2 || !ok3 {
		return Identity{}, false
	}
	return Identity{UserID: userID, VaultID: vaultID, DeviceID: deviceID}, true
}
