import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import axios from 'axios';
import Header from '../../components/Header';
import Footer from '../../components/Footer';
import Sidebar from '../../components/Sidebar';
import Swal from 'sweetalert2';

const UpdateUser = ({ userInfo, handleLogout }) => {
    const navigate = useNavigate();
    const location = useLocation();
    const dataItems = location.state?.newUser || JSON.parse(localStorage.getItem('editDeviceData'));
    localStorage.setItem('editDeviceData', JSON.stringify(dataItems));
    const [username, setUsername] = useState(dataItems?.username || '');
    const [email_id] = useState(dataItems?.email_id || ''); // Read-only, so no need for state
    const [password, setPassword] = useState(dataItems?.password || ''); // Read-only, so no need for state
    const [phone_no, setPhoneNo] = useState(dataItems?.phone_no || '');
    const [role_name] = useState(dataItems?.role_name || ''); // Read-only, so no need for state
    const [status, setStatus] = useState(dataItems?.status ? 'true' : 'false'); // Initialize with Active or Inactive
    const [errorMessage, setErrorMessage] = useState('');

     // Store initial values
     const [initialValues, setInitialValues] = useState({
        username: dataItems?.username || '',
        phone_no: dataItems?.phone_no || '',
        password: dataItems?.password || '',
        status: dataItems?.status ? 'true' : 'false',
    });

    // Check if any field has been modified
    const isModified = (
        username !== initialValues.username ||
        phone_no !== initialValues.phone_no ||
        password !== initialValues.password ||
        status !== initialValues.status
    );

    // update client users
    const updateClientUser = async (e) => {
        e.preventDefault();
        
        // phone number validation
        const phoneRegex = /^\d{10}$/;
        if (!phone_no || !phoneRegex.test(phone_no)) {
            setErrorMessage('Phone number must be a 10-digit number.');
            return;
        }
 
        // Validate password
        const passwordRegex = /^\d{4}$/;
        if (!password) {
            setErrorMessage("Password can't be empty.");
            return;
        }
        if (!passwordRegex.test(password)) {
            setErrorMessage('Oops! Password must be a 4-digit number.');
            return;
        }

        try {
            const formattedUserData = {
                user_id: dataItems?.user_id,
                username: username,
                phone_no: parseInt(phone_no),
                modified_by: userInfo.data.email_id,
                password: parseInt(password), // Assuming this is not supposed to be changed
                status: status === 'true',
            };

            const response = await axios.post(`/reselleradmin/UpdateUser`, formattedUserData);

            if (response.status === 200) {
                // Handle success
                Swal.fire({
                    position: "center",
                    icon: "success",
                    title: "User updated successfully",
                    showConfirmButton: false,
                    timer: 1500
                });
                navigate('/reselleradmin/ManageUsers');
            } else {
                const responseData = await response.json();
                // Handle other status codes
                Swal.fire({
                    position: "center",
                    icon: "Error",
                    title: "Failed to update user. Please try again, " + responseData.message,
                    showConfirmButton: false,
                    timer: 1500
                });
                // setErrorMessage('Failed to update user. Please try again, ');
            }
        } catch (error) {
            console.error('Error updating user:', error);
        }
    };

    // back manage user page
    const goBack = () => {
        navigate('/reselleradmin/ManageUsers');
    };

    // search
    const handleStatusChange = (e) => {
        setStatus(e.target.value);
    };

    useEffect(() => {
        // Update initial values if dataItems changes
        setInitialValues({
            username: dataItems?.username || '',
            phone_no: dataItems?.phone_no || '',
            password: dataItems?.password || '',
            status: dataItems?.status ? 'true' : 'false',
        });
    }, [dataItems]);

    return (
        <div className='container-scroller'>
            {/* Header */}
            <Header userInfo={userInfo} handleLogout={handleLogout} />
            <div className="container-fluid page-body-wrapper" style={{ paddingTop: '40px' }}>
                {/* Sidebar */}
                <Sidebar />
                <div className="main-panel">
                    <div className="content-wrapper">
                        <div className="row">
                            <div className="col-md-12 grid-margin">
                                <div className="row">
                                    <div className="col-12 col-xl-8 mb-4 mb-xl-0">
                                        <h3 className="font-weight-bold">Edit User</h3>
                                    </div>
                                    <div className="col-12 col-xl-4">
                                        <div className="justify-content-end d-flex">
                                            <button type="button" className="btn btn-success" onClick={goBack} style={{ marginRight: '10px' }}>Back</button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div className="row">
                            <div className="col-lg-12 grid-margin stretch-card">
                                <div className="card">
                                    <div className="card-body">
                                        <div className="col-12 grid-margin">
                                            <div className="card">
                                                <div className="card-body">
                                                    <h4 className="card-title">Update Users</h4>
                                                    <form className="form-sample" onSubmit={updateClientUser}>
                                                        <div className="row">
                                                            <div className="col-md-6">
                                                                <div className="form-group row">
                                                                    <label className="col-sm-12 col-form-label labelInput">User Name</label>
                                                                    <div className="col-sm-12">
                                                                        <input
                                                                            type="text"
                                                                            className="form-control"
                                                                            value={username}
                                                                            maxLength={25}
                                                                            onChange={(e) => {
                                                                                const sanitizedValue = e.target.value.replace(/[^a-zA-Z0-9 ]/g, '');
                                                                                setUsername(sanitizedValue.slice(0, 25));
                                                                            }}
                                                                            readOnly
                                                                            required
                                                                        />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="col-md-6">
                                                                <div className="form-group row">
                                                                    <label className="col-sm-12 col-form-label labelInput">Phone No</label>
                                                                    <div className="col-sm-12">
                                                                        <input
                                                                            type="text"
                                                                            className="form-control"
                                                                            value={phone_no}
                                                                            maxLength={10}
                                                                            onChange={(e) => {
                                                                                const sanitizedValue = e.target.value.replace(/[^0-9]/g, '');
                                                                                setPhoneNo(sanitizedValue.slice(0, 10));
                                                                            }}
                                                                            required
                                                                        />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="col-md-6">
                                                                <div className="form-group row">
                                                                    <label className="col-sm-12 col-form-label labelInput">Email ID</label>
                                                                    <div className="col-sm-12">
                                                                        <input
                                                                            type="email"
                                                                            className="form-control"
                                                                            value={email_id}
                                                                            readOnly
                                                                        />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="col-md-6">
                                                                <div className="form-group row">
                                                                    <label className="col-sm-12 col-form-label labelInput">Password</label>
                                                                    <div className="col-sm-12">
                                                                        <input
                                                                            type="text"
                                                                            className="form-control"
                                                                            value={password}
                                                                            maxLength={4}
                                                                            onChange={(e) => {
                                                                                const sanitizedValue = e.target.value.replace(/[^0-9]/g, '');
                                                                                setPassword(sanitizedValue.slice(0, 4));
                                                                            }}
                                                                            required
                                                                        />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="col-md-6">
                                                                <div className="form-group row">
                                                                    <label className="col-sm-12 col-form-label labelInput">Role Name</label>
                                                                    <div className="col-sm-12">
                                                                        <input
                                                                            type="text"
                                                                            className="form-control"
                                                                            value={role_name}
                                                                            readOnly
                                                                        />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div className="col-md-6">
                                                                <div className="form-group row">
                                                                    <label className="col-sm-12 col-form-label labelInput">Status</label>
                                                                    <div className="col-sm-12">
                                                                        <select
                                                                            className="form-control"
                                                                            value={status}
                                                                            onChange={handleStatusChange}
                                                                            required
                                                                            style={{ color: "black" }}
                                                                        >
                                                                            <option value="true">Active</option>
                                                                            <option value="false">DeActive</option>
                                                                        </select>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>
                                                        {errorMessage && <div className="text-danger">{errorMessage}</div>}
                                                        <div style={{ textAlign: 'center', padding:'15px'}}>
                                                            <button type="submit" className="btn btn-primary mr-2" disabled={!isModified}>Update</button>
                                                        </div>
                                                    </form>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    {/* Footer */}
                    <Footer />
                </div>
            </div>
        </div>
    );
};

export default UpdateUser;
