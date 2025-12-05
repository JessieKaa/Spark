package database

import (
	"Spark/modules"
	"Spark/server/common"
	"database/sql"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

var (
	db   *sql.DB
	once sync.Once
)

// DeviceRecord 数据库中存储的设备记录
type DeviceRecord struct {
	ID          string `json:"id"`
	Remark      string `json:"remark"`
	OS          string `json:"os"`
	Arch        string `json:"arch"`
	LAN         string `json:"lan"`
	WAN         string `json:"wan"`
	MAC         string `json:"mac"`
	Hostname    string `json:"hostname"`
	Username    string `json:"username"`
	OfflineTime int64  `json:"offline_time"`
	CreatedAt   int64  `json:"created_at"`
	UpdatedAt   int64  `json:"updated_at"`
}

// Init 初始化数据库连接
func Init(dbPath string) error {
	var err error
	once.Do(func() {
		db, err = sql.Open("sqlite3", dbPath)
		if err != nil {
			return
		}

		// 设置连接池参数
		db.SetMaxOpenConns(1) // SQLite 只支持单写
		db.SetMaxIdleConns(1)
		db.SetConnMaxLifetime(time.Hour)

		// 创建设备表
		err = createTables()
	})
	return err
}

// createTables 创建数据库表
func createTables() error {
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS devices (
		id TEXT PRIMARY KEY,
		remark TEXT DEFAULT '',
		os TEXT DEFAULT '',
		arch TEXT DEFAULT '',
		lan TEXT DEFAULT '',
		wan TEXT DEFAULT '',
		mac TEXT DEFAULT '',
		hostname TEXT DEFAULT '',
		username TEXT DEFAULT '',
		offline_time INTEGER DEFAULT 0,
		created_at INTEGER DEFAULT 0,
		updated_at INTEGER DEFAULT 0
	);
	CREATE INDEX IF NOT EXISTS idx_devices_hostname ON devices(hostname);
	CREATE INDEX IF NOT EXISTS idx_devices_remark ON devices(remark);
	CREATE INDEX IF NOT EXISTS idx_devices_offline_time ON devices(offline_time);
	`

	_, err := db.Exec(createTableSQL)
	if err != nil {
		common.Error(nil, "DB_CREATE_TABLE", "fail", err.Error(), nil)
		return err
	}

	common.Info(nil, "DB_INIT", "success", "", nil)
	return nil
}

// Close 关闭数据库连接
func Close() error {
	if db != nil {
		return db.Close()
	}
	return nil
}

// SaveDevice 保存或更新设备信息
func SaveDevice(device *modules.Device) error {
	if db == nil {
		return nil
	}

	now := time.Now().Unix()

	// 使用 UPSERT 语法（INSERT OR REPLACE）
	query := `
	INSERT INTO devices (id, remark, os, arch, lan, wan, mac, hostname, username, offline_time, created_at, updated_at)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT(id) DO UPDATE SET
		remark = CASE WHEN excluded.remark != '' THEN excluded.remark ELSE devices.remark END,
		os = excluded.os,
		arch = excluded.arch,
		lan = excluded.lan,
		wan = excluded.wan,
		mac = excluded.mac,
		hostname = excluded.hostname,
		username = excluded.username,
		offline_time = excluded.offline_time,
		updated_at = excluded.updated_at
	`

	_, err := db.Exec(query,
		device.ID,
		device.Remark,
		device.OS,
		device.Arch,
		device.LAN,
		device.WAN,
		device.MAC,
		device.Hostname,
		device.Username,
		device.OfflineTime,
		now,
		now,
	)

	if err != nil {
		common.Error(nil, "DB_SAVE_DEVICE", "fail", err.Error(), map[string]any{
			"device_id": device.ID,
		})
		return err
	}

	return nil
}

// UpdateDeviceOfflineTime 更新设备离线时间
func UpdateDeviceOfflineTime(deviceID string, offlineTime int64) error {
	if db == nil {
		return nil
	}

	query := `UPDATE devices SET offline_time = ?, updated_at = ? WHERE id = ?`
	_, err := db.Exec(query, offlineTime, time.Now().Unix(), deviceID)
	if err != nil {
		common.Error(nil, "DB_UPDATE_OFFLINE", "fail", err.Error(), map[string]any{
			"device_id": deviceID,
		})
		return err
	}
	return nil
}

// UpdateDeviceRemark 更新设备备注
func UpdateDeviceRemark(deviceID string, remark string) error {
	if db == nil {
		return nil
	}

	query := `UPDATE devices SET remark = ?, updated_at = ? WHERE id = ?`
	_, err := db.Exec(query, remark, time.Now().Unix(), deviceID)
	if err != nil {
		common.Error(nil, "DB_UPDATE_REMARK", "fail", err.Error(), map[string]any{
			"device_id": deviceID,
		})
		return err
	}
	return nil
}

// GetDevice 获取单个设备信息
func GetDevice(deviceID string) (*DeviceRecord, error) {
	if db == nil {
		return nil, nil
	}

	query := `SELECT id, remark, os, arch, lan, wan, mac, hostname, username, offline_time, created_at, updated_at FROM devices WHERE id = ?`
	row := db.QueryRow(query, deviceID)

	var record DeviceRecord
	err := row.Scan(
		&record.ID,
		&record.Remark,
		&record.OS,
		&record.Arch,
		&record.LAN,
		&record.WAN,
		&record.MAC,
		&record.Hostname,
		&record.Username,
		&record.OfflineTime,
		&record.CreatedAt,
		&record.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return &record, nil
}

// GetAllDevices 获取所有设备列表
func GetAllDevices() ([]*DeviceRecord, error) {
	if db == nil {
		return nil, nil
	}

	query := `SELECT id, remark, os, arch, lan, wan, mac, hostname, username, offline_time, created_at, updated_at FROM devices ORDER BY updated_at DESC`
	rows, err := db.Query(query)
	if err != nil {
		common.Error(nil, "DB_GET_ALL_DEVICES", "fail", err.Error(), nil)
		return nil, err
	}
	defer rows.Close()

	var devices []*DeviceRecord
	for rows.Next() {
		var record DeviceRecord
		err := rows.Scan(
			&record.ID,
			&record.Remark,
			&record.OS,
			&record.Arch,
			&record.LAN,
			&record.WAN,
			&record.MAC,
			&record.Hostname,
			&record.Username,
			&record.OfflineTime,
			&record.CreatedAt,
			&record.UpdatedAt,
		)
		if err != nil {
			continue
		}
		devices = append(devices, &record)
	}

	return devices, nil
}

// GetOfflineDevices 获取离线设备列表
func GetOfflineDevices() ([]*DeviceRecord, error) {
	if db == nil {
		return nil, nil
	}

	query := `SELECT id, remark, os, arch, lan, wan, mac, hostname, username, offline_time, created_at, updated_at FROM devices WHERE offline_time > 0 ORDER BY offline_time DESC`
	rows, err := db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []*DeviceRecord
	for rows.Next() {
		var record DeviceRecord
		err := rows.Scan(
			&record.ID,
			&record.Remark,
			&record.OS,
			&record.Arch,
			&record.LAN,
			&record.WAN,
			&record.MAC,
			&record.Hostname,
			&record.Username,
			&record.OfflineTime,
			&record.CreatedAt,
			&record.UpdatedAt,
		)
		if err != nil {
			continue
		}
		devices = append(devices, &record)
	}

	return devices, nil
}

// DeleteDevice 删除设备记录
func DeleteDevice(deviceID string) error {
	if db == nil {
		return nil
	}

	query := `DELETE FROM devices WHERE id = ?`
	_, err := db.Exec(query, deviceID)
	if err != nil {
		common.Error(nil, "DB_DELETE_DEVICE", "fail", err.Error(), map[string]any{
			"device_id": deviceID,
		})
		return err
	}
	return nil
}

// SearchDevices 搜索设备
func SearchDevices(keyword string) ([]*DeviceRecord, error) {
	if db == nil {
		return nil, nil
	}

	query := `SELECT id, remark, os, arch, lan, wan, mac, hostname, username, offline_time, created_at, updated_at 
	          FROM devices 
	          WHERE id LIKE ? OR remark LIKE ? OR hostname LIKE ? 
	          ORDER BY updated_at DESC`

	pattern := "%" + keyword + "%"
	rows, err := db.Query(query, pattern, pattern, pattern)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []*DeviceRecord
	for rows.Next() {
		var record DeviceRecord
		err := rows.Scan(
			&record.ID,
			&record.Remark,
			&record.OS,
			&record.Arch,
			&record.LAN,
			&record.WAN,
			&record.MAC,
			&record.Hostname,
			&record.Username,
			&record.OfflineTime,
			&record.CreatedAt,
			&record.UpdatedAt,
		)
		if err != nil {
			continue
		}
		devices = append(devices, &record)
	}

	return devices, nil
}

// DeviceRecordToModule 将数据库记录转换为 modules.Device
func DeviceRecordToModule(record *DeviceRecord) *modules.Device {
	return &modules.Device{
		ID:          record.ID,
		Remark:      record.Remark,
		OS:          record.OS,
		Arch:        record.Arch,
		LAN:         record.LAN,
		WAN:         record.WAN,
		MAC:         record.MAC,
		Hostname:    record.Hostname,
		Username:    record.Username,
		OfflineTime: record.OfflineTime,
	}
}
