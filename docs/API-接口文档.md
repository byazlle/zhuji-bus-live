# 诸暨公交实时查询 API 技术文档

## 一、基础信息

### API 基础地址
```
https://zjcx.zhuji.gov.cn:9443
```

### GitHub 参考项目
```
https://github.com/fgh1995/zhujibus
```
> 这是一个开源的诸暨公交Android APP，所有接口信息都来自它的源码。
> 核心API文件：`app/src/main/java/org/zjfgh/zhujibus/BusApiClient.java`

### 认证说明
**无需登录！无需浙里办！无需支付宝！**
只需要在请求里带上固定的headers即可，userToken是写死的固定字符串。

---

## 二、请求格式

### 通用请求结构
所有接口都是 **POST + JSON**，请求体统一格式：
```json
{
  "h": {
    "deviceId": "test123456",
    "userToken": "userToken",
    "codeValue": "330681",
    "appCode": "330681",
    "sourceCodeValue": "330681",
    "appVersion": "1.0.0",
    "deviceTypeName": "weixin"
  },
  "b": {
    // 业务参数，不同接口不一样
  }
}
```

### 固定Headers说明
| 字段 | 值 | 说明 |
|---|---|---|
| deviceId | 随便填，如 "test123456" | 设备标识，无校验 |
| userToken | "userToken" | 固定值，写死的，不是登录态 |
| codeValue | "330681" | 诸暨行政区划代码 |
| appCode | "330681" | 同上 |
| sourceCodeValue | "330681" | 同上 |
| appVersion | "1.0.0" | 随便填 |
| deviceTypeName | "weixin" | 固定值 |

---

## 三、接口列表

### 1. 搜索公交线路
**路径：** `/gzcx-busServer/client/busLine/searchBusLines`

**请求参数（b字段）：**
| 字段 | 类型 | 说明 |
|---|---|---|
| lineName | string | 线路名称，如 "1路"、"105"、"156" |
| needGeometry | int | 是否需要线路坐标，0=不需要，1=需要 |

**返回示例：**
```json
{
  "returnFlag": "200",
  "returnInfo": "成功",
  "code": "200",
  "msg": "成功",
  "data": {
    "pageNum": 1,
    "pageSize": 10,
    "total": 196,
    "list": [
      {
        "endStation": "草塔停车场",
        "lineName": "1路",
        "startStation": "西施殿公交首末站"
      }
    ]
  }
}
```

---

### 2. 查询线路详情（站点列表）
**路径：** `/gzcx-busServer/client/busLine/queryLine`

**请求参数（b字段）：**
| 字段 | 类型 | 说明 |
|---|---|---|
| lineName | string | 线路名称，如 "1路" |
| needGeometry | int | 是否需要线路坐标，0=不需要 |

**返回示例：**
```json
{
  "returnFlag": "200",
  "data": {
    "areaCode": "330681",
    "lineName": "1路",
    "up": {
      "id": "330681112",
      "endStation": "草塔停车场",
      "startStation": "西施殿公交首末站",
      "startFirst": "06:20:00",
      "startLast": "17:50:00",
      "lineLength": 16,
      "stationList": [
        {
          "stationName": "西施殿公交首末站",
          "id": "33068111201",
          "stationOrder": 1,
          "poiOriginLon": 120.236828,
          "poiOriginLat": 29.697174
        }
      ]
    },
    "down": {
      "id": "330681111",
      "endStation": "西施殿公交首末站",
      "startStation": "草塔停车场",
      "stationList": [...]
    }
  }
}
```

**关键字段：**
- `up.id`：上行线路ID，查实时车辆要用
- `down.id`：下行线路ID
- `up.stationList`：上行站点列表，按顺序排列
- `startFirst` / `startLast`：首末班时间

---

### 3. 查询实时车辆位置（核心！）
**路径：** `/gzcx-busServer/client/bus/vehicle/dynamic/line/details`

**请求参数（b字段）：**
| 字段 | 类型 | 说明 |
|---|---|---|
| lineId | string | 线路ID，从上面"查询线路详情"接口的 up.id / down.id 拿到 |

**返回示例：**
```json
{
  "returnFlag": "200",
  "data": {
    "busAverageSpeed": 240,
    "clientShowVehicleNumber": 3,
    "list": [
      {
        "vehicleOrder": 3,
        "lng": 120.236384286115,
        "lat": 29.7072522100379,
        "distance": 238,
        "gpsTime": "2026-11-02 14:32:53",
        "plateNumber": "浙D08578D",
        "isArriveStation": 0
      }
    ]
  }
}
```

**关键字段：**
- `list[].lng` / `list[].lat`：车辆经纬度
- `list[].plateNumber`：车牌号
- `list[].gpsTime`：GPS定位时间（实时！）
- `list[].distance`：距离当前站的距离（米）
- `list[].vehicleOrder`：车辆在整条线路上的位置序号
- `list[].isArriveStation`：是否到站（0=未到站，1=已到站）

---

### 4. 搜索站点
**路径：** `/gzcx-busServer/client/station/searchStation`

**请求参数（b字段）：**
| 字段 | 类型 | 说明 |
|---|---|---|
| stationName | string | 站点名称关键词 |
| page | int | 页码，从1开始 |
| offset | int | 每页条数 |

---

### 5. 查询站点到站信息
**路径：** `/gzcx-busServer/client/bus/vehicle/dynamic/station/details`

**请求参数（b字段）：**
| 字段 | 类型 | 说明 |
|---|---|---|
| lineIds | string | 线路ID，多个用逗号分隔 |
| stationIds | string | 站点ID，多个用逗号分隔 |

---

## 四、完整请求示例（curl）

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "h": {
      "deviceId": "test123456",
      "userToken": "userToken",
      "codeValue": "330681",
      "appCode": "330681",
      "sourceCodeValue": "330681",
      "appVersion": "1.0.0",
      "deviceTypeName": "weixin"
    },
    "b": {
      "lineName": "1路",
      "needGeometry": 0
    }
  }' \
  "https://zjcx.zhuji.gov.cn:9443/gzcx-busServer/client/busLine/searchBusLines"
```

---

## 五、已验证的线路

| 线路 | 起点 | 终点 | 实时车辆 |
|---|---|---|---|
| 1路 | 西施殿公交首末站 | 草塔停车场 | ✅ 有 |
| 105A路 | 客运中心 | 徐里（竹蓬） | ✅ 有 |
| 156路 | 郭家停车场 | 山汀（山后） | ✅ 接口可用，当前无车 |
| 总数 | - | - | 196条线路 |

---

## 六、注意事项

1. **CORS 跨域**：✅ **实测可直接跨域**。响应头带 `Access-Control-Allow-Origin: *`，`OPTIONS` 预检也放行 `POST` + `content-type`。
   所以纯前端网页（包括 `file://` 打开的本地文件和 Android WebView）都能直接调用，**不需要自建后端代理**。
2. **HTTPS 证书**：正规证书。但在部分 Windows + Git Bash 环境下 curl 会报 `CRYPT_E_NO_REVOCATION_CHECK`，加 `--ssl-no-revoke` 即可，与接口本身无关。
3. **Frequency**：没测出限流。车辆接口按 10 秒轮询未出现异常。
4. **数据更新**：GPS 时间实时，约 10~30 秒更新一次，位置误差几十米。
5. **城乡公交也有**：105 路那种城乡支线，这个 API 里也全有。

---

## 七、实测补充（2026-11 校验结论）

### 7.1 线路搜索的坑

- `lineName` **不能为空字符串**，否则返回 `{"code":"203","data":"codeValue or lineName is null"}`。
  要拿全部线路得传 `"路"`（返回 386 条）或 `"线"`（补上"专线"类）。
- 分页参数是 **`page` + `offset`**，其中 `offset` 表示**每页条数**（不是偏移量），默认每页 10 条。
  ```json
  { "lineName": "路", "needGeometry": 0, "page": 2, "offset": 50 }
  ```
- 全网去重后共 **395 条线路**（386 条含"路"+ 9 条专线：青春巴士夜间专线A/B、高湖专线、凰桐河上专线、通勤2号A线、通勤3号线等）。

### 7.2 `vehicleOrder` 到底是什么（最容易搞错）

用经纬度反算校验了多条线路，结论：

| 字段 | 真实含义 |
|---|---|
| `vehicleOrder` | 车**已经到达/驶离**的那一站，等于该方向 `stationList[].stationOrder`（1 起），**不是"下一站"** |
| `distance` | 到**下一站**（`vehicleOrder + 1`）的距离，单位米 |
| `isArriveStation` | 1 = 正停靠站台；0 = 在路上 |

因此"车还有几站到我"的正确算法是：

```
剩余站数 = 我的站的 stationOrder − 车的 vehicleOrder
```

- 结果 `< 0` → 车已经开过去了，应当隐藏
- 结果 `= 0` 且 `distance` 已超过本站到下一站距离的一半 → 车刚离站走远，也应当隐藏
- 结果 `= 0` 且 `isArriveStation = 1`（或刚离站）→ 显示"已到站"

把 `vehicleOrder` 当数组下标用会整体偏 1 站，是最常见的错误。

### 7.3 `queryLine` 里可用的线路级字段

```json
{
  "startStation": "西施殿公交首末站",
  "endStation": "草塔停车场",
  "startFirst": "06:20:00",
  "startLast": "17:50:00",
  "lineLength": 16,        // 公里
  "totalPrice": 1.0,       // 票价（元）
  "id": "330681112",       // 该方向的线路 ID，查车辆要用
  "stationList": [ ... ]
}
```

`stationList[].lastDistance` 是相邻站间距（米），站点经纬度异常时可拿来兜底算距离。

### 7.4 环线

部分线路（如 `青春巴士夜间专线A`）只有 `up` 没有 `down`，且 `startStation === endStation`。
前端需要兼容"只有一个方向"和"起终点同名"两种情况。

---

## 八、参考项目源码位置

GitHub仓库：`https://github.com/fgh1995/zhujibus`

核心文件：
- `app/src/main/java/org/zjfgh/zhujibus/BusApiClient.java` — 所有API接口定义
- `app/src/main/java/org/zjfgh/zhujibus/WebSocketManager.java` — WebSocket实时推送（可选）
- `诸暨公交ws服务端/` — 作者自己搭的WebSocket中转服务端

如果有问题，可以直接去这个仓库的源码里找答案。
