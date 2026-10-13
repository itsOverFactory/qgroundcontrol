#include "MountFactGroupListModel.h"
#include "MAVLinkLib.h"

MountFactGroupListModel::MountFactGroupListModel(QObject *parent)
    : FactGroupListModel("mount", parent)
{

}

bool MountFactGroupListModel::_shouldHandleMessage(const mavlink_message_t &message, QList<uint32_t> &ids) const
{
    ids.clear();

    switch (message.msgid) {
    case MAVLINK_MSG_ID_DISTANCE_SENSOR_MOUNT:
        ids.append(mavlink_msg_distance_sensor_mount_get_id(&message));
        return true;
    case MAVLINK_MSG_ID_MOUNT_RANGEFINDER_STATUS:
        ids.append(mavlink_msg_mount_rangefinder_status_get_id(&message));
        return true;
    default:
        return false; // not supported
    }
}

FactGroupWithId *MountFactGroupListModel::_createFactGroupWithId(uint32_t id)
{
    return new MountFactGroup(id, this);
}

MountFactGroup::MountFactGroup(uint32_t mountId, QObject *parent)
    : FactGroupWithId(1000, QStringLiteral(":/json/Vehicle/MountFact.json"), parent)
{
    _addFact(&_rotationNoneFact);
    _addFact(&_rotationYaw45Fact);
    _addFact(&_rotationYaw90Fact);
    _addFact(&_rotationYaw135Fact);
    _addFact(&_rotationYaw180Fact);
    _addFact(&_rotationYaw225Fact);
    _addFact(&_rotationYaw270Fact);
    _addFact(&_rotationYaw315Fact);
    _addFact(&_rotationPitch90Fact);
    _addFact(&_rotationPitch270Fact);
    _addFact(&_rotationCustomFact);
    _addFact(&_minDistanceFact);
    _addFact(&_maxDistanceFact);

    _idFact.setRawValue(mountId);

    _rangefinderStatusTimer.setSingleShot(true);
    _rangefinderStatusTimer.setInterval(_rangefinderStatusTimeoutMs);
    (void) connect(&_rangefinderStatusTimer, &QTimer::timeout, this, [this]() { _setRangefinderStatusAvailable(false); });
}

void MountFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    switch (message.msgid) {
    case MAVLINK_MSG_ID_DISTANCE_SENSOR_MOUNT:
        _handleDistanceSensorMount(message);
        break;
    case MAVLINK_MSG_ID_MOUNT_RANGEFINDER_STATUS:
        _handleMountRangefinderStatus(message);
        break;
    default:
        break;
    }
}

void MountFactGroup::_handleDistanceSensorMount(const mavlink_message_t &message)
{
    mavlink_distance_sensor_mount_t distanceSensor{};
    mavlink_msg_distance_sensor_mount_decode(&message, &distanceSensor);

    if (distanceSensor.id != id()->rawValue().toUInt()) {
        // Disregard messages which are not from this mount
        return;
    }

    struct orientation2Fact_s {
        const MAV_SENSOR_ORIENTATION orientation;
        Fact *fact;
    };

    const orientation2Fact_s rgOrientation2Fact[] = {
        { MAV_SENSOR_ROTATION_NONE, rotationNone() },
        { MAV_SENSOR_ROTATION_YAW_45, rotationYaw45() },
        { MAV_SENSOR_ROTATION_YAW_90, rotationYaw90() },
        { MAV_SENSOR_ROTATION_YAW_135, rotationYaw135() },
        { MAV_SENSOR_ROTATION_YAW_180, rotationYaw180() },
        { MAV_SENSOR_ROTATION_YAW_225, rotationYaw225() },
        { MAV_SENSOR_ROTATION_YAW_270, rotationYaw270() },
        { MAV_SENSOR_ROTATION_YAW_315, rotationYaw315() },
        { MAV_SENSOR_ROTATION_PITCH_90, rotationPitch90() },
        { MAV_SENSOR_ROTATION_PITCH_270, rotationPitch270() },
        { MAV_SENSOR_ROTATION_CUSTOM, rotationCustom() },
    };

    for (const orientation2Fact_s &orientation2Fact : rgOrientation2Fact) {
        if (orientation2Fact.orientation == distanceSensor.orientation) {
            orientation2Fact.fact->setRawValue(distanceSensor.current_distance / 100.0); // cm to meters
            break;
        }
    }

    minDistance()->setRawValue(distanceSensor.min_distance / 100.0);
    maxDistance()->setRawValue(distanceSensor.max_distance / 100.0);

    _setTelemetryAvailable(true);
}

void MountFactGroup::_handleMountRangefinderStatus(const mavlink_message_t &message)
{
    mavlink_mount_rangefinder_status_t status{};
    mavlink_msg_mount_rangefinder_status_decode(&message, &status);

    if (status.id != id()->rawValue().toUInt()) {
        // discard messages which are not from this mount
        return;
    }

    const bool enabled = (status.enabled == 1);
    if (enabled != _rangefinderEnabled) {
        _rangefinderEnabled = enabled;
        emit rangefinderEnabledChanged();
    }

    _setRangefinderStatusAvailable(true);
    _rangefinderStatusTimer.start();
}

void MountFactGroup::_setRangefinderStatusAvailable(bool available)
{
    if (available != _rangefinderStatusAvailable) {
        _rangefinderStatusAvailable = available;
        emit rangefinderStatusAvailableChanged();
    }
}
