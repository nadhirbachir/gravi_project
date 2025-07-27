using gravi_application.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Interfaces
{
    public interface IUserPersonFactoryService
    {
        Task<(string Message, UserDTO? NewUser)> CreateUserWithPersonAsync(AddUserDTO newUserDTO);
    }
}
