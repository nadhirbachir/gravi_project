using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Interfaces
{
    public interface IPersonRepository
    {
        Task<(string Message, long? Result)> AddPerson(Person newPerson);
        Task<(string Message, bool Result)> UpdatePerson(Person person);
        Task<(string Message, bool Result)> DeletePerson(long personId);
        Task<Person?> FindPersonById(long personId);
    }
}
