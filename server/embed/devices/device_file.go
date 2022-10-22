package devices

import (
	"Spark/server/common"
	"Spark/server/config"
	"Spark/utils"
	"bytes"
	"errors"
	"os"
)

type DeviceInfo struct {
	ID       string `json:"id"`
	Os       string `json:"os"`
	Arch     string `json:"arch"`
	Hostname string `json:"hostname"`
	Username string `json:"username"`
	Remark   string `json:"remark"`
}

func WriteDeviceInfo(info *DeviceInfo) {
	js, err := utils.JSON.Marshal(info)
	if err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		return
	}
	if _, err := os.Stat(config.Config.DeviceInfoFile); errors.Is(err, os.ErrNotExist) {
		file, err := os.Create(config.Config.DeviceInfoFile)
		if err != nil {
			common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
			return
		}
		if _, err = file.Write(js); err != nil {
			common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		}
		return
	}

	fileBytes, err := os.ReadFile(config.Config.DeviceInfoFile)
	if err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		return
	}

	if bytes.Compare(js, fileBytes) == 0 {
		return
	}

	fileWriter, err := os.OpenFile(config.Config.DeviceInfoFile, os.O_WRONLY, 0666)
	if err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		return
	}
	_, err = fileWriter.Write(js)
	if err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		return
	}
}
