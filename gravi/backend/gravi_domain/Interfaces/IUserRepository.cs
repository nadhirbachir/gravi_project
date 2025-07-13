using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Interfaces
{
    public interface IUserRepository
    {
        Task<(string Message, long? Result)> AddUser(User newUser);
        Task<(string Message, bool Result)> UpdateUser(User user);
        Task<(string Message, bool Result)> DeleteUser(long userId, string passwordHash);
        Task<User?> FindUserById(long userId);
        Task<User?> FindUserByPersonId(long personId);
        Task<User?> FindUserByEmail(string email);
        Task<User?> FindUserByUsername(string username);
        Task<User?> LogUser(string usernameOrEmail, string password);
    }
}
