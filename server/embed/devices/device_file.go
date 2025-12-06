package devices

import (
	"Spark/server/common"
	"Spark/server/config"
	"Spark/utils"
	"errors"
	"fmt"
	"os"
	"sync"
)

type DeviceInfo struct {
	ID       string `json:"id"`
	Os       string `json:"os"`
	Arch     string `json:"arch"`
	Hostname string `json:"hostname"`
	Username string `json:"username"`
	Remark   string `json:"remark"`
}

var lock sync.Mutex

func WriteDeviceInfo(info *DeviceInfo) {
	lock.Lock()
	defer lock.Unlock()
	if _, err := os.Stat(config.Config.DeviceInfoFile); errors.Is(err, os.ErrNotExist) {
		file, err := os.Create(config.Config.DeviceInfoFile)
		if err != nil {
			common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
			return
		}
		_ = file.Close()
	}

	fileBytes, err := os.ReadFile(config.Config.DeviceInfoFile)
	if err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		return
	}

	var fileDeviceInfo []*DeviceInfo
	if err := utils.JSON.Unmarshal(fileBytes, &fileDeviceInfo); err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
	} else {
		for _, cInfo := range fileDeviceInfo {
			if cInfo.ID == info.ID {
				return
			}
		}
	}

	fmt.Printf("Read fileDeviceInfo: %+v", fileDeviceInfo)
	fileDeviceInfo = append(fileDeviceInfo, info)
	fileWriter, err := os.OpenFile(config.Config.DeviceInfoFile, os.O_WRONLY, 0666)
	if err != nil {
		common.Error(nil, "WRITE_DEVICE_INFO", "fail", err.Error(), nil)
		return
	}

	js, err := utils.JSON.Marshal(fileDeviceInfo)
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
