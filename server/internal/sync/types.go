package sync

// itemDTO is the wire representation of an item, used both in the push
// response's conflicts list and in GET /v1/sync/changes. Nonce and
// Ciphertext are nil (omitted) for tombstones.
type itemDTO struct {
	ItemID     string   `json:"item_id"`
	Kind       string   `json:"kind"`
	Rev        int64    `json:"rev"`
	UpdatedAt  int64    `json:"updated_at"`
	Deleted    bool     `json:"deleted"`
	DeviceID   string   `json:"device_id"`
	Nonce      *string  `json:"nonce"`
	Ciphertext *string  `json:"ciphertext"`
	BlobRefs   []string `json:"blob_refs"`
}

type changesResponse struct {
	ServerRev int64     `json:"server_rev"`
	NextSince int64     `json:"next_since"`
	HasMore   bool      `json:"has_more"`
	Items     []itemDTO `json:"items"`
}

type pushItemDTO struct {
	ItemID     string   `json:"item_id"`
	Kind       string   `json:"kind"`
	BaseRev    int64    `json:"base_rev"`
	UpdatedAt  int64    `json:"updated_at"`
	Deleted    bool     `json:"deleted"`
	Nonce      *string  `json:"nonce"`
	Ciphertext *string  `json:"ciphertext"`
	BlobRefs   []string `json:"blob_refs"`
}

type pushRequest struct {
	DeviceID string        `json:"device_id"`
	Items    []pushItemDTO `json:"items"`
}

type acceptedDTO struct {
	ItemID string `json:"item_id"`
	Rev    int64  `json:"rev"`
}

type pushResponse struct {
	ServerRev int64         `json:"server_rev"`
	Accepted  []acceptedDTO `json:"accepted"`
	Conflicts []itemDTO     `json:"conflicts"`
}
